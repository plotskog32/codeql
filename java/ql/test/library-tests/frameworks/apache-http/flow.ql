import java
import semmle.code.java.dataflow.TaintTracking
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.security.XSS

class Conf extends TaintTracking::Configuration {
  Conf() { this = "qltest:frameworks:apache-http" }

  override predicate isSource(DataFlow::Node n) {
    n.asExpr().(MethodAccess).getMethod().hasName("taint")
    or
    n instanceof RemoteFlowSource
  }

  override predicate isSink(DataFlow::Node n) {
    exists(MethodAccess ma | ma.getMethod().hasName("sink") | n.asExpr() = ma.getAnArgument())
    or
    n instanceof XssSink
  }
}

from DataFlow::Node src, DataFlow::Node sink, Conf conf
where conf.hasFlow(src, sink)
select src, sink
