/**
 * @name Hard-coded credentials
 * @description Credentials are hard coded in the source code of the application.
 * @kind path-problem
 * @problem.severity error
 * @precision high
 * @id cs/hardcoded-credentials
 * @tags security
 *       external/cwe/cwe-259
 *       external/cwe/cwe-321
 *       external/cwe/cwe-798
 */
import csharp
import semmle.code.csharp.security.dataflow.HardcodedCredentials::HardcodedCredentials
import semmle.code.csharp.dataflow.DataFlow::DataFlow::PathGraph

from TaintTrackingConfiguration c, Source source, Sink sink, string value
where
  c.hasFlow(source, sink) and
  // Print the source value if it's available
  if exists(source.asExpr().getValue()) then
    value = "The hard-coded value \"" + source.asExpr().getValue() + "\""
  else
    value = "This hard-coded value"
select source, source.getPathNode(c), sink.getPathNode(c),
  value + " flows to " + sink.getSinkDescription() + ".",
  sink, sink.getSinkName(), sink.getSupplementaryElement(),
  sink.getSupplementaryElement().toString()
