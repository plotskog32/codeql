/**
 * @name Uncontrolled data used in path expression
 * @description Accessing paths influenced by users can allow an attacker to access unexpected resources.
 * @kind path-problem
 * @problem.severity error
 * @sub-severity high
 * @precision high
 * @id py/path-injection
 * @tags correctness
 *       security
 *       external/owasp/owasp-a1
 *       external/cwe/cwe-022
 *       external/cwe/cwe-023
 *       external/cwe/cwe-036
 *       external/cwe/cwe-073
 *       external/cwe/cwe-099
 */

import python
import semmle.python.security.Paths

/* Sources */
import semmle.python.web.HttpRequest

/* Sinks */
import semmle.python.security.injection.Path



from TaintedNode srcnode, TaintedNode sinknode, TaintSource src, TaintSink sink
where src.flowsToSink(sink) and srcnode.getNode() = src and sinknode.getNode() = sink

select sink, srcnode, sinknode, "This path depends on $@.", src, "a user-provided value"
