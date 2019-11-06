/**
 * @name Client-side cross-site scripting through exception
 * @description User input being part of an exception allows for 
 *              cross-site scripting if that exception ends as input
 *              to the DOM.  
 * @kind path-problem
 * @problem.severity error
 * @precision low
 * @id js/xss-through-exception
 * @tags security
 *       external/cwe/cwe-079
 *       external/cwe/cwe-116
 */

import javascript
import semmle.javascript.security.dataflow.ExceptionXss::ExceptionXss
import DataFlow::PathGraph

from
  Configuration cfg, DataFlow::PathNode source, DataFlow::PathNode sink
where
  cfg.hasFlowPath(source, sink) and
  not any(ConfigurationNoException c).hasFlow(source.getNode(), sink.getNode())
select sink.getNode(), source, sink,
  sink.getNode().(Sink).getVulnerabilityKind() + " vulnerability due to $@.", source.getNode(),
  "user-provided value"
