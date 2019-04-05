/**
 * @name Suspicious pointer scaling to char
 * @description Implicit scaling of pointer arithmetic expressions
 *              can cause buffer overflow conditions.
 * @kind problem
 * @id cpp/incorrect-pointer-scaling-char
 * @problem.severity warning
 * @precision low
 * @tags security
 *       external/cwe/cwe-468
 */
import cpp
import semmle.code.cpp.controlflow.SSA
import IncorrectPointerScalingCommon

private Type baseType(Type t) {
  (
    exists (PointerType dt
    | dt = t.getUnspecifiedType() and
      result = dt.getBaseType().getUnspecifiedType()) or
    exists (ArrayType at
    | at = t.getUnspecifiedType() and
      (not at.getBaseType().getUnspecifiedType() instanceof ArrayType) and
      result = at.getBaseType().getUnspecifiedType()) or
    exists (ArrayType at, ArrayType at2
    | at = t.getUnspecifiedType() and
      at2 = at.getBaseType().getUnspecifiedType() and
      result = baseType(at2))
  )
  // Make sure that the type has a size and that it isn't ambiguous.  
  and strictcount(result.getSize()) = 1
}

from Expr dest, Type destType, Type sourceType, Type sourceBase,
     Type destBase, Location sourceLoc
where exists(pointerArithmeticParent(dest))
  and exprSourceType(dest, sourceType, sourceLoc)
  and sourceBase = baseType(sourceType)
  and destType = dest.getFullyConverted().getType()
  and destBase = baseType(destType)
  and destBase.getSize() != sourceBase.getSize()
  and not dest.isInMacroExpansion()

  // If the source type is a char* or void* then don't
  // produce a result, because it is likely to be a false
  // positive.
  and not (sourceBase instanceof CharType)
  and not (sourceBase instanceof VoidType)

   // Don't produce an alert if the dest type is `char *` but the
   // expression contains a `sizeof`, which is probably correct.  For
   // example:
   // ```
   //   int x[3] = {1,2,3};
   //   char* p = (char*)x;
   //   return *(int*)(p + (2 * sizeof(int)))
   // ```
   and not (
     destBase instanceof CharType and
     dest.getParent().(Expr).getAChild*() instanceof SizeofOperator
   )

  // Don't produce an alert if the root expression computes
  // an offset, rather than a pointer. For example:
  // ```
  //     (p + 1) - q
  // ```
  and forall(Expr parent |
             parent = pointerArithmeticParent+(dest) |
             parent.getFullyConverted().getType().getUnspecifiedType() instanceof PointerType)

  // Only produce alerts that are not produced by `IncorrectPointerScaling.ql`.
  and (destBase instanceof CharType)
select
  dest,
  "This pointer might have type $@ (size " + sourceBase.getSize() +
  "), but the pointer arithmetic here is done with type " +
  destType + " (size " + destBase.getSize() + ").",
  sourceLoc, sourceBase.toString()
