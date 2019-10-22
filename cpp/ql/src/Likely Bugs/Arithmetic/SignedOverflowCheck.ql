/**
 * @name Undefined result of signed test for overflow
 * @description Testing for overflow by adding a value to a variable
 *              to see if it "wraps around" works only for
 *              `unsigned` integer values.
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @id cpp/signed-overflow-check
 * @tags reliability
 *       security
 */

import cpp
private import semmle.code.cpp.valuenumbering.GlobalValueNumbering
private import semmle.code.cpp.rangeanalysis.SimpleRangeAnalysis

from RelationalOperation ro, AddExpr add, VariableAccess va1, VariableAccess va2
where
  ro.getAnOperand() = add and
  add.getAnOperand() = va1 and
  ro.getAnOperand() = va2 and
  globalValueNumber(va1) = globalValueNumber(va2) and
  add.getType().getUnspecifiedType().(IntegralType).isSigned() and
  exprMightOverflowPositively(add)
select ro, "Testing for signed overflow may produce undefined results."
