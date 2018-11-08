/**
 * @name Client-side URL redirect
 * @description Client-side URL redirection based on unvalidated user input
 *              may cause redirection to malicious web sites.
 * @kind path-problem
 * @problem.severity error
 * @precision high
 * @id js/client-side-unvalidated-url-redirection
 * @tags security
 *       external/cwe/cwe-079
 *       external/cwe/cwe-116
 *       external/cwe/cwe-601
 */

import javascript
import semmle.javascript.security.dataflow.ClientSideUrlRedirect::ClientSideUrlRedirect
import DataFlow::PathGraph

from Configuration cfg, DataFlow::PathNode source, DataFlow::PathNode sink
where cfg.hasPathFlow(source, sink)
select sink.getNode(), "Untrusted URL redirection due to $@.", source, "user-provided value"
