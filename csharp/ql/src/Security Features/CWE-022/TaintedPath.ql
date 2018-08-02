/**
 * @name Uncontrolled data used in path expression
 * @description Accessing paths influenced by users can allow an attacker to access unexpected resources.
 * @kind problem
 * @problem.severity error
 * @precision high
 * @id cs/path-injection
 * @tags security
 *       external/cwe/cwe-022
 *       external/cwe/cwe-023
 *       external/cwe/cwe-036
 *       external/cwe/cwe-073
 *       external/cwe/cwe-099
 */
import csharp
import semmle.code.csharp.security.dataflow.TaintedPath::TaintedPath

from TaintTrackingConfiguration c, Source source, Sink sink
where c.hasFlow(source, sink)
select sink, "$@ flows to here and is used in a path.", source, "User-provided value"
