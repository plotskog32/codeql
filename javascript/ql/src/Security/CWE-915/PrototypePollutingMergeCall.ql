/**
 * @name Prototype-polluting merge call
 * @description Recursively merging a user-controlled object into another object
 *              can allow an attacker to modify the built-in Object prototype,
 *              and possibly escalate to remote code execution or cross-site scripting.
 * @kind path-problem
 * @problem.severity error
 * @precision high
 * @id js/prototype-pollution
 * @tags security
 *       external/cwe/cwe-078
 *       external/cwe/cwe-094
 *       external/cwe/cwe-400
 *       external/cwe/cwe-915
 */

import javascript
import semmle.javascript.security.dataflow.PrototypePollution::PrototypePollution
import DataFlow::PathGraph
import semmle.javascript.dependencies.Dependencies

from
  Configuration cfg, DataFlow::PathNode source, DataFlow::PathNode sink, string moduleName,
  Locatable dependencyLoc
where
  cfg.hasFlowPath(source, sink) and
  sink.getNode().(Sink).dependencyInfo(moduleName, dependencyLoc)
select sink.getNode(), source, sink,
  "Prototype pollution caused by merging a user-controlled value from $@ using a vulnerable version of $@.",
  source, "here", dependencyLoc, moduleName
