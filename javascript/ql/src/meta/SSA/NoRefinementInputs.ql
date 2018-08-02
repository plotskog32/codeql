/**
 * @name Refinement node without inputs
 * @description Every SSA refinement node should have exactly one input.
 * @kind problem
 * @problem.severity error
 * @id js/sanity/dead-refinement-node
 * @tags sanity
 */

import javascript

from SsaRefinementNode ref
where not exists(ref.getAnInput())
select ref, "Refinement node without inputs."
