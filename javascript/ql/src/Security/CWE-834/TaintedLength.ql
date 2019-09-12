/**
 * @name Tainted .length in loop condition
 * @description Iterating over an object with a user-controlled .length
 *              property can cause indefinite looping
 * @kind path-problem
 * @problem.severity warning
 * @id js/loop-bound-injection
 * @tags security
 *       external/cwe/cwe-834
 * @precision medium
 */

import javascript
import semmle.javascript.security.dataflow.TaintedLength::TaintedLength

from Configuration dataflow, DataFlow::PathNode source, DataFlow::PathNode sink
where dataflow.hasFlowPath(source, sink)
select sink, source, sink,
  "Iterating over user-controlled object with a potentially unbounded .length property from $@.",
  source, "here"
