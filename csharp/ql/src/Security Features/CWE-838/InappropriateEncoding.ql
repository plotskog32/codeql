/**
* @name Inappropriate encoding
* @description Using an inappropriate encoding may give unintended results and may
*              pose a security risk.
* @kind problem
* @problem.severity error
* @precision low
* @id cs/inappropriate-encoding
* @tags security
*       external/cwe/cwe-838
*/

import csharp
import DataFlow
import semmle.code.csharp.frameworks.System
import semmle.code.csharp.frameworks.system.Net
import semmle.code.csharp.frameworks.system.Web
import semmle.code.csharp.frameworks.system.web.UI
import semmle.code.csharp.security.dataflow.SqlInjection
import semmle.code.csharp.security.dataflow.XSS
import semmle.code.csharp.security.dataflow.UrlRedirect
import semmle.code.csharp.security.Sanitizers

/**
 * A configuration for specifying expressions that must be
 * encoded, along with a set of potential valid encoded values.
 */
abstract class RequiresEncodingConfiguration extends TaintTracking::Configuration {
  bindingset[this]
  RequiresEncodingConfiguration() { any() }

  /** Gets a textual representation of this kind of encoding requirement. */
  abstract string getKind();

  /** Holds if `e` is an expression whose value must be encoded. */
  abstract predicate requiresEncoding(Node n);

  /** Holds if `e` is a possible valid encoded value. */
  predicate isPossibleEncodedValue(Expr e) { none() }

  /**
   * Holds if `encodedValue` is a possibly ill-encoded value that reaches
   * `sink`, where `sink` is an expression of kind `kind` that is required
   * to be encoded.
   */
  predicate hasWrongEncoding(Expr encodedValue, Expr sink, string kind) {
    hasFlow(exprNode(encodedValue), exprNode(sink)) and
    kind = this.getKind()
  }

  override predicate isSource(Node source) {
    // all encoded values that do not match this configuration are
    // considered sources
    exists(Expr e |
      e = source.asExpr() |
      e instanceof EncodedValue and
      not this.isPossibleEncodedValue(e)
    )
  }

  override predicate isSink(Node sink) {
    this.requiresEncoding(sink)
  }

  override predicate isSanitizer(Node sanitizer) {
    this.isPossibleEncodedValue(sanitizer.asExpr())
  }
}

/** An encoded value, for example a call to `HttpServerUtility.HtmlEncode`. */
class EncodedValue extends Expr {
  EncodedValue() {
    any(RequiresEncodingConfiguration c).isPossibleEncodedValue(this)
    or
    this = any(SystemWebHttpUtility c).getAJavaScriptStringEncodeMethod().getACall()
    or
    // Also try to identify user-defined encoders, which are likely wrong
    exists(Method m, string name, string regexp |
      this.(MethodCall).getTarget() = m and
      m.fromSource() and
      m.getName().toLowerCase() = name and
      name.toLowerCase().regexpMatch(regexp) and
      regexp = ".*(encode|saniti(s|z)e|cleanse|escape).*"
    )
  }
}

module EncodingConfigurations {
  /** An encoding configuration for SQL expressions. */
  class SqlExpr extends RequiresEncodingConfiguration {
    SqlExpr() {
      this = "SqlExpr"
    }

    override string getKind() {
      result = "SQL expression"
    }

    override predicate requiresEncoding(Node n) {
      n instanceof SqlInjection::Sink
    }

    // no override for `isPossibleEncodedValue` as SQL parameters should
    // be used instead of explicit encoding

    override predicate isSource(Node source) {
      super.isSource(source) or
      // consider quote-replacing calls as additional sources for
      // SQL expressions (e.g., `s.Replace("\"", "\"\"")`)
      source.asExpr() = any(MethodCall mc |
        mc.getTarget() = any(SystemStringClass c).getReplaceMethod() and
        mc.getArgument(0).getValue().regexpMatch("\"|'|`")
      )
    }
  }

  /** An encoding configuration for HTML expressions. */
  class HtmlExpr extends RequiresEncodingConfiguration {
    HtmlExpr() {
      this = "HtmlExpr"
    }

    override string getKind() {
      result = "HTML expression"
    }

    override predicate requiresEncoding(Node n) {
      n instanceof XSS::HtmlSink
    }

    override predicate isPossibleEncodedValue(Expr e) {
      e instanceof HtmlSanitizedExpr
    }
  }

  /** An encoding configuration for URL expressions. */
  class UrlExpr extends RequiresEncodingConfiguration {
    UrlExpr() {
      this = "UrlExpr"
    }

    override string getKind() {
      result = "URL expression"
    }

    override predicate requiresEncoding(Node n) {
      n instanceof UrlRedirect::Sink
    }

    override predicate isPossibleEncodedValue(Expr e) {
      e instanceof UrlSanitizedExpr
    }
  }
}

from RequiresEncodingConfiguration c, Expr encodedValue, Expr sink, string kind
where c.hasWrongEncoding(encodedValue, sink, kind)
select sink, "This " + kind + " may include data from a $@.", encodedValue, "possibly inappropriately encoded value"
