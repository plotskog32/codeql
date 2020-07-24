/**
 * @name Unsecure basic authentication
 * @description Basic authentication only obfuscates username/password in Base64 encoding, which can be easily recognized and reversed. Transmission of sensitive information not in HTTPS is vulnerable to packet sniffing.
 * @kind problem
 * @id java/unsecure-basic-auth
 * @tags security
 *       external/cwe-522
 *       external/cwe-319
 */

import java
import semmle.code.java.frameworks.Networking
import semmle.code.java.dataflow.TaintTracking
import DataFlow::PathGraph

/**
 * The Java class `org.apache.http.message.AbstractHttpMessage`. Popular subclasses include `HttpGet`, `HttpPost`, and `HttpPut`.
 */
class ApacheHttpRequest extends RefType {
  ApacheHttpRequest() { hasQualifiedName("org.apache.http.message", "AbstractHttpMessage") }
}

/**
 * Class of Java URL constructor
 */
class URLConstructor extends ClassInstanceExpr {
  URLConstructor() { this.getConstructor().getDeclaringType() instanceof TypeUrl }

  Expr stringArg() {
    // Query only in URL's that were constructed by calling the single parameter string constructor.
    this.getConstructor().getNumberOfParameters() = 1 and
    this.getConstructor().getParameter(0).getType() instanceof TypeString and
    result = this.getArgument(0)
  }
}

/**
 * The type `java.net.URLConnection`.
 */
class TypeHttpUrlConnection extends RefType {
  TypeHttpUrlConnection() { hasQualifiedName("java.net", "HttpURLConnection") }
}

/**
 * String of HTTP URLs not in private domains
 */
class HttpString extends StringLiteral {
  HttpString() {
    // Match URLs with the HTTP protocol and without private IP addresses to reduce false positives.
    exists(string s | this.getRepresentedString() = s |
      s.matches("http://%") and
      not s.matches("%/localhost%") and
      not s.matches("%/127.0.0.1%") and
      not s.matches("%/10.%") and
      not s.matches("%/172.16.%") and
      not s.matches("%/192.168.%")
    )
  }
}

/**
 * String concatenated with `HttpString`
 */
predicate builtFromHttpStringConcat(Expr expr) {
  expr instanceof HttpString
  or
  exists(AddExpr concatExpr | concatExpr = expr |
    builtFromHttpStringConcat(concatExpr.getLeftOperand())
  )
  or
  exists(AddExpr concatExpr | concatExpr = expr |
    exists(Expr arg | arg = concatExpr.getLeftOperand() | arg instanceof HttpString)
  )
  or
  exists(Expr other | builtFromHttpStringConcat(other) |
    exists(Variable var | var.getAnAssignedValue() = other and var.getAnAccess() = expr)
  )
}

/**
 * The methods `addHeader()` and `setHeader` declared in ApacheHttpRequest invoked for basic authentication.
 */
class AddBasicAuthHeaderMethodAccess extends MethodAccess {
  AddBasicAuthHeaderMethodAccess() {
    this.getMethod().getDeclaringType() instanceof ApacheHttpRequest and
    (this.getMethod().hasName("addHeader") or this.getMethod().hasName("setHeader")) and
    this.getArgument(0).(CompileTimeConstantExpr).getStringValue() = "Authorization" and
    exists(Expr arg1 |
      arg1 = this.getArgument(1) and //Check three patterns
      (
        arg1 //String authStringEnc = "Basic ...."; post.addHeader("Authorization", authStringEnc)
            .(VarAccess)
            .getVariable()
            .getAnAssignedValue()
            .(StringLiteral)
            .getRepresentedString()
            .matches("Basic %") or
        arg1.(CompileTimeConstantExpr).getStringValue().matches("Basic %") or //post.addHeader("Authorization", "Basic ....")
        arg1.(AddExpr).getLeftOperand().(StringLiteral).getRepresentedString().matches("Basic %") //post.addHeader("Authorization", "Basic "+authStringEnc)
      )
    ) and
    exists(VarAccess request, VariableAssign va, ConstructorCall cc, Expr arg0 |
      this.getQualifier() = request and //Check the method invocation with the pattern post.addHeader("Authorization", "Basic " + authStringEnc)
      va.getDestVar() = request.getVariable() and
      va.getSource() = cc and
      cc.getArgument(0) = arg0 and
      builtFromHttpStringConcat(arg0) // Check url string
    )
  }
}

/** The `openConnection` method of Java URL. Not to include `openStream` since it won't be used in this query. */
class HttpURLOpenMethod extends Method {
  HttpURLOpenMethod() {
    this.getDeclaringType() instanceof TypeUrl and
    this.getName() = "openConnection"
  }
}

/**
 * Tracks the flow of data from parameter of URL constructor to the url instance
 */
class URLConstructorTaintStep extends TaintTracking::AdditionalTaintStep {
  override predicate step(DataFlow::Node node1, DataFlow::Node node2) {
    exists(URLConstructor u |
      node1.asExpr() = u.stringArg() and
      node2.asExpr() = u
    )
  }
}

/**
 * Tracks the flow of data from `openConnection` method to the connection object
 */
class OpenHttpURLTaintStep extends TaintTracking::AdditionalTaintStep {
  override predicate step(DataFlow::Node node1, DataFlow::Node node2) {
    exists(MethodAccess ma, VariableAssign va |
      ma.getMethod() instanceof HttpURLOpenMethod and
      ma.getQualifier() = node1.asExpr() and
      (
        ma = va.getSource()
        or
        exists(CastExpr ce |
          ce.getExpr() = ma and
          ce = va.getSource() and
          ce.getControlFlowNode().getASuccessor() = va //With a type cast like HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        )
      ) and
      node2.asExpr() = va.getDestVar().getAnAccess()
    )
  }
}

class HttpStringToHttpURLOpenMethodFlowConfig extends TaintTracking::Configuration {
  HttpStringToHttpURLOpenMethodFlowConfig() {
    this = "UnsecureBasicAuth::HttpStringToHttpURLOpenMethodFlowConfig"
  }

  override predicate isSource(DataFlow::Node src) { src.asExpr() instanceof HttpString }

  override predicate isSink(DataFlow::Node sink) {
    sink.asExpr().(VarAccess).getVariable().getType() instanceof TypeUrlConnection or
    sink.asExpr().(VarAccess).getVariable().getType() instanceof TypeHttpUrlConnection // Somehow TypeHttpUrlConnection isn't instance of TypeUrlConnection
  }

  override predicate isAdditionalTaintStep(DataFlow::Node node1, DataFlow::Node node2) {
    exists(DataFlow::Node nodem |
      any(URLConstructorTaintStep uts).step(node1, nodem) and
      any(OpenHttpURLTaintStep ots).step(nodem, node2)
    )
  }

  override predicate isSanitizer(DataFlow::Node node) {
    node.getType() instanceof PrimitiveType or node.getType() instanceof BoxedType
  }
}

/**
 * The method `setRequestProperty()` declared in URL Connection invoked for basic authentication.
 */
class SetBasicAuthPropertyMethodAccess extends MethodAccess {
  SetBasicAuthPropertyMethodAccess() {
    this.getMethod().getDeclaringType() instanceof TypeUrlConnection and
    this.getMethod().hasName("setRequestProperty") and
    this.getArgument(0).(CompileTimeConstantExpr).getStringValue() = "Authorization" and
    exists(Expr arg1 |
      arg1 = this.getArgument(1) and //Check three patterns
      (
        arg1 //String authStringEnc = "Basic ...."; conn.setRequestProperty("Authorization", authStringEnc)
            .(VarAccess)
            .getVariable()
            .getAnAssignedValue()
            .(StringLiteral)
            .getRepresentedString()
            .matches("Basic %") or
        arg1.(CompileTimeConstantExpr).getStringValue().matches("Basic %") or //conn.setRequestProperty("Authorization", "Basic ....")
        arg1.(AddExpr).getLeftOperand().(StringLiteral).getRepresentedString().matches("Basic %") //conn.setRequestProperty("Authorization", "Basic "+authStringEnc)
      )
    ) and
    exists(VarAccess conn, DataFlow::PathNode source, DataFlow::PathNode sink, HttpString s |
      this.getQualifier() = conn and //HttpURLConnection conn = (HttpURLConnection) url.openConnection();
      source.getNode().asExpr() = s and
      sink.getNode().asExpr() = conn.getVariable().getAnAccess() and
      any(HttpStringToHttpURLOpenMethodFlowConfig c).hasFlowPath(source, sink)
    )
  }
}

from MethodAccess ma
where
  ma instanceof AddBasicAuthHeaderMethodAccess or
  ma instanceof SetBasicAuthPropertyMethodAccess
select ma, "Unsafe basic authentication"
