/** Provides classes to reason about header splitting attacks. */

import java
import semmle.code.java.dataflow.DataFlow
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.frameworks.Servlets
import semmle.code.java.frameworks.JaxWS

/** Header-splitting sinks. Expressions that end up in an HTTP header. */
abstract class HeaderSplittingSink extends DataFlow::Node { }

/** Sources that cannot be used to perform a header splitting attack. */
abstract class SafeHeaderSplittingSource extends DataFlow::Node {
  SafeHeaderSplittingSource() { this instanceof RemoteFlowSource }
}

/** Servlet and JaxWS sinks susceptible to header splitting. */
private class ServletHeaderSplittingSink extends HeaderSplittingSink {
  ServletHeaderSplittingSink() {
    exists(ResponseAddCookieMethod m, MethodAccess ma |
      ma.getMethod() = m and
      this.asExpr() = ma.getArgument(0)
    )
    or
    exists(ResponseAddHeaderMethod m, MethodAccess ma |
      ma.getMethod() = m and
      this.asExpr() = ma.getAnArgument()
    )
    or
    exists(ResponseSetHeaderMethod m, MethodAccess ma |
      ma.getMethod() = m and
      this.asExpr() = ma.getAnArgument()
    )
    or
    exists(JaxRsResponseBuilder builder, Method m |
      m = builder.getAMethod() and m.getName() = "header"
    |
      this.asExpr() = m.getAReference().getArgument(1)
    )
  }
}

/** Sources of data considered safe to use by header splitting sinks. */
private class DefaultSafeHeaderSplittingSource extends SafeHeaderSplittingSource {
  DefaultSafeHeaderSplittingSource() {
    this.asExpr().(MethodAccess).getMethod() instanceof HttpServletRequestGetHeaderMethod or
    this.asExpr().(MethodAccess).getMethod() instanceof CookieGetNameMethod
  }
}
