/**
 * @name Ambiguously signed bit-field member
 * @description Bit fields with integral types should have explicit signedness
 *              only. For example, use `unsigned int` rather than `int`. It is
 *              implementation specific whether an `int`-typed bit field is
 *              signed, so there could be unexpected sign extension or
 *              overflow.
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @id cpp/ambiguously-signed-bit-field
 * @tags reliability
 *       readability
 *       language-features
 *       external/cwe/cwe-190
 */
import cpp

from BitField bf
where not bf.getType().getUnspecifiedType().(IntegralType).isExplicitlySigned()
  and not bf.getType().getUnspecifiedType().(IntegralType).isExplicitlyUnsigned()
  and not bf.getType().getUnspecifiedType() instanceof Enum
  and not bf.getType().getUnspecifiedType() instanceof BoolType
  // At least for C programs on Windows, BOOL is a common typedef for a type
  // representing BoolType.
  and not bf.getType().hasName("BOOL")
  // If this is true, then there cannot be unsigned sign extension or overflow.
  and not bf.getDeclaredNumBits() = bf.getType().getSize() * 8
  and not bf.isAnonymous()
select bf, "Bit field " + bf.getName() + " of type " +  bf.getUnderlyingType().getName() +  " should have explicitly unsigned integral, explicitly signed integral, or enumeration type."
