/**
 * @name Hard-coded credential in sensitive call
 * @description Using a hard-coded credential in a sensitive call may compromise security.
 * @kind problem
 * @problem.severity error
 * @precision low
 * @id java/hardcoded-credential-sensitive-call
 * @tags security
 *       external/cwe/cwe-798
 */
import java
import semmle.code.java.dataflow.DataFlow
import semmle.code.java.dataflow.DataFlow2
import HardcodedCredentials

class HardcodedCredentialSourceCallConfiguration extends DataFlow::Configuration {
  HardcodedCredentialSourceCallConfiguration() { this = "HardcodedCredentialSourceCallConfiguration" }
  override predicate isSource(DataFlow::Node n) {
    n.asExpr() instanceof HardcodedExpr
  }
  override predicate isSink(DataFlow::Node n) {
    n.asExpr() instanceof FinalCredentialsSourceSink
  }
}

class HardcodedCredentialSourceCallConfiguration2 extends DataFlow2::Configuration {
  HardcodedCredentialSourceCallConfiguration2() { this = "HardcodedCredentialSourceCallConfiguration2" }
  override predicate isSource(DataFlow::Node n) {
    n.asExpr() instanceof CredentialsSourceSink
  }
  override predicate isSink(DataFlow::Node n) {
    n.asExpr() instanceof CredentialsSink
  }
}

class FinalCredentialsSourceSink extends CredentialsSourceSink {
  FinalCredentialsSourceSink() {
    not exists(HardcodedCredentialSourceCallConfiguration2 conf, CredentialsSink other | this != other |
      conf.hasFlow(DataFlow::exprNode(this), DataFlow::exprNode(other))
    )
  }
}

from FinalCredentialsSourceSink sink, HardcodedExpr source, HardcodedCredentialSourceCallConfiguration conf
where conf.hasFlow(DataFlow::exprNode(source), DataFlow::exprNode(sink))
select source, "Hard-coded value flows to $@.",
  sink, "sensitive call"
