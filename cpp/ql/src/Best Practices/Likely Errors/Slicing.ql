/**
 * @name Slicing
 * @description Assigning a non-reference instance of a derived type to a variable of the base type slices off all members added by the derived class, and can cause an unexpected state.
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @id cpp/slicing
 * @tags reliability
 *       correctness
 *       types
 *       security
 *       external/cwe/cwe-843
 */
import cpp

//see http://www.cs.ualberta.ca/~hoover/Courses/201/201-New-Notes/lectures/section/slice.htm
//Does not find anything in rivers (unfortunately)
from AssignExpr e, Class lhsType, Class rhsType
where e.getLValue().getType() = lhsType
  and e.getRValue().getType() = rhsType
  and rhsType.getABaseClass+() = lhsType
  and exists(Declaration m | rhsType.getAMember() = m and
                        not m.(VirtualFunction).isPure()) //add additional checks for concrete members in in-between supertypes
select e, "This assignment expression slices from type $@ to $@",
  rhsType, rhsType.getName(),
  lhsType, lhsType.getName()
