/**
 * @name Tainted .length looping
 * @description If server-side code iterates over a user-controlled object with
 *              an arbitrary .length value, then an attacker can trick the server
 *              to loop infinitely. 
 * @kind path-problem
 * @problem.severity warning
 * @id js/tainted-length-looping
 * @tags security
 * @precision low
 */

import javascript

import semmle.javascript.security.dataflow.TaintedLength::TaintedLength

from
  Configuration dataflow, DataFlow::PathNode source, DataFlow::PathNode sink
where dataflow.hasFlowPath(source, sink)
select sink, source, sink,
  "Iterating over user controlled object with an unbounded .length property $@.",
  source, "here"
