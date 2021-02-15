/**
 * @name Cors header being set from remote source
 * @description Cors header is being set from remote source, allowing to control the origin.
 * @kind path-problem
 * @problem.severity error
 * @precision high
 * @id java/unvalidated-cors-origin-set
 * @tags security
 *       external/cwe/cwe-346
 */

import java
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.frameworks.Servlets
import semmle.code.java.dataflow.TaintTracking
import DataFlow::PathGraph

/**
 *  Holds if `header` sets `Access-Control-Allow-Credentials` to `true`. This ensures fair chances of exploitability.
 */
private predicate setsAllowCredentials(MethodAccess header) {
  (
    header.getMethod() instanceof ResponseSetHeaderMethod or
    header.getMethod() instanceof ResponseAddHeaderMethod
  ) and
  header.getArgument(0).(CompileTimeConstantExpr).getStringValue().toLowerCase() =
    "access-control-allow-credentials" and
  header.getArgument(1).(CompileTimeConstantExpr).getStringValue() = "true"
}

class CorsProbableCheckAccess extends MethodAccess {
  CorsProbableCheckAccess() {
    getMethod().getName() = ["contains", "equals"] and
    getMethod().getDeclaringType().getQualifiedName() =
      ["java.util.List<String>", "java.util.ArrayList<String>", "java.lang.String"]
  }
}

private Expr getAccessControlAllowOriginHeaderName() {
  result.(CompileTimeConstantExpr).getStringValue().toLowerCase() = "access-control-allow-origin"
}

class CorsOriginConfig extends TaintTracking::Configuration {
  CorsOriginConfig() { this = "CorsOriginConfig" }

  override predicate isSource(DataFlow::Node source) { source instanceof RemoteFlowSource }

  override predicate isSink(DataFlow::Node sink) {
    exists(MethodAccess corsheader, MethodAccess allowcredentialsheader |
      (
        corsheader.getMethod() instanceof ResponseSetHeaderMethod or
        corsheader.getMethod() instanceof ResponseAddHeaderMethod
      ) and
      getAccessControlAllowOriginHeaderName() = corsheader.getArgument(0) and
      setsAllowCredentials(allowcredentialsheader) and
      corsheader.getEnclosingCallable() = allowcredentialsheader.getEnclosingCallable() and
      sink.asExpr() = corsheader.getArgument(1)
    )
  }

  /*
   * This should ideally check, the origin being validated against a list/array-list.
   * or function being used to validate the origin, which has a flow from its parameter to any of the CorsProbableCheckAccess functions
   */

  override predicate isSanitizer(DataFlow::Node node) {
    node.asExpr() = any(CorsProbableCheckAccess ma).getAnArgument()
    or
    exists(MethodAccess ma, CorsProbableCheckAccess ca |
      ma.getMethod().calls(ca.getMethod()) and
      DataFlow::localExprFlow(ma.getMethod().getAParameter().getAnAccess(), ca.getAnArgument()) and
      (node.asExpr() = ma.getAnArgument() or node.asExpr() = ma.getAnArgument().getAChildExpr())
    )
  }
}

from DataFlow::PathNode source, DataFlow::PathNode sink, CorsOriginConfig conf
where conf.hasFlowPath(source, sink)
select sink.getNode(), source, sink, "Cors header is being set using user controlled value $@.",
  source.getNode(), "user-provided value"
