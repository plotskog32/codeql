/**
 * @name Overly complex __del__ method
 * @description __del__ methods may be called at arbitrary times, perhaps never called at all, and should be simple.
 * @kind problem
 * @tags efficiency
 *       maintainability
 *       complexity
 *       statistical
 *       non-attributable
 * @problem.severity recommendation
 * @sub-severity low
 * @precision high
 * @id py/overly-complex-delete
 */

import python

from FunctionObject method
where
    exists(ClassObject c |
        c.declaredAttribute("__del__") = method and
        method.getFunction().getMetrics().getCyclomaticComplexity() > 3
    )
select method, "Overly complex '__del__' method."
