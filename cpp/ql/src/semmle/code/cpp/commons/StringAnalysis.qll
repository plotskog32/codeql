import semmle.code.cpp.exprs.Expr
import semmle.code.cpp.controlflow.SSA

/**
 * Holds if a value can flow directly from one expr to another.
 */
predicate canValueFlow(Expr fromExpr, Expr toExpr)
{
  (
    // value propagated via a definition use pair
    exists(Variable v, SsaDefinition def | fromExpr = def.getAnUltimateDefiningValue(v) |
      toExpr = def.getAUse(v)
    )
  ) or (
    // expr -> containing parenthesized expression
    fromExpr = toExpr.(ParenthesisExpr).getExpr()
  ) or (
    // R value -> containing assignment expression ('=' assignment)
    fromExpr = toExpr.(AssignExpr).getRValue()
  ) or (
    // then -> containing ternary (? :) operator
    fromExpr = toExpr.(ConditionalExpr).getThen()
  ) or (
    // else -> containing ternary (? :) operator
    fromExpr = toExpr.(ConditionalExpr).getElse()
  )
}

/**
 * An analysed null terminated string.
 */
class AnalysedString extends Expr
{
  AnalysedString()
  {
    this.getType().getUnspecifiedType() instanceof ArrayType or
    this.getType().getUnspecifiedType() instanceof PointerType
  }

  /**
   * Gets the maximum length (including null) this string can be, when this
   * can be calculated.
   */
  int getMaxLength()
  {
    // take the longest AnalysedString it's value could 'flow' from; however if even one doesn't
    // return a value (this essentially means 'infinity') we can't return a value either.
    result = max(AnalysedString expr, int toMax | (canValueFlow*(expr, this)) and (toMax = expr.(StringLiteral).getOriginalLength()) | toMax) // maximum length
    and
    forall(AnalysedString expr | canValueFlow(expr, this) | exists(expr.getMaxLength())) // all sources return a value (recursive)
  }
}

/**
 * A call to a strlen like function.
 */
class StrlenCall extends FunctionCall {
  StrlenCall() {
    this.getTarget().hasGlobalName("strlen") or
    this.getTarget().hasGlobalName("wcslen") or
    this.getTarget().hasGlobalName("_mbslen") or
    this.getTarget().hasGlobalName("_mbslen_l") or
    this.getTarget().hasGlobalName("_mbstrlen") or
    this.getTarget().hasGlobalName("_mbstrlen_l")
  }

  /**
   * The string argument passed into this strlen-like call.
   */
  Expr getStringExpr() {
    result = this.getArgument(0)
  }
}
