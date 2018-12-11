/**
 * Provides classes and predicates for range analysis.
 *
 * An inferred bound can either be a specific integer or the abstract value of
 * an IR `Instruction`.
 *
 * If an inferred bound relies directly on a condition, then this condition is
 * reported as the reason for the bound.
 */

// TODO: update the following comment
/*
 * This library tackles range analysis as a flow problem. Consider e.g.:
 * ```
 *   len = arr.length;
 *   if (x < len) { ... y = x-1; ... y ... }
 * ```
 * In this case we would like to infer `y <= arr.length - 2`, and this is
 * accomplished by tracking the bound through a sequence of steps:
 * ```
 *   arr.length --> len = .. --> x < len --> x-1 --> y = .. --> y
 * ```
 *
 * In its simplest form the step relation `E1 --> E2` relates two expressions
 * such that `E1 <= B` implies `E2 <= B` for any `B` (with a second separate
 * step relation handling lower bounds). Examples of such steps include
 * assignments `E2 = E1` and conditions `x <= E1` where `E2` is a use of `x`
 * guarded by the condition.
 *
 * In order to handle subtractions and additions with constants, and strict
 * comparisons, the step relation is augmented with an integer delta. With this
 * generalization `E1 --(delta)--> E2` relates two expressions and an integer
 * such that `E1 <= B` implies `E2 <= B + delta` for any `B`. This corresponds
 * to the predicate `boundFlowStep`.
 *
 * The complete range analysis is then implemented as the transitive closure of
 * the step relation summing the deltas along the way. If `E1` transitively
 * steps to `E2`, `delta` is the sum of deltas along the path, and `B` is an
 * interesting bound equal to the value of `E1` then `E2 <= B + delta`. This
 * corresponds to the predicate `bounded`.
 *
 * Phi nodes need a little bit of extra handling. Consider `x0 = phi(x1, x2)`.
 * There are essentially two cases:
 * - If `x1 <= B + d1` and `x2 <= B + d2` then `x0 <= B + max(d1,d2)`.
 * - If `x1 <= B + d1` and `x2 <= x0 + d2` with `d2 <= 0` then `x0 <= B + d1`.
 * The first case is for whenever a bound can be proven without taking looping
 * into account. The second case is relevant when `x2` comes from a back-edge
 * where we can prove that the variable has been non-increasing through the
 * loop-iteration as this means that any upper bound that holds prior to the
 * loop also holds for the variable during the loop.
 * This generalizes to a phi node with `n` inputs, so if
 * `x0 = phi(x1, ..., xn)` and `xi <= B + delta` for one of the inputs, then we
 * also have `x0 <= B + delta` if we can prove either:
 * - `xj <= B + d` with `d <= delta` or
 * - `xj <= x0 + d` with `d <= 0`
 * for each input `xj`.
 *
 * As all inferred bounds can be related directly to a path in the source code
 * the only source of non-termination is if successive redundant (and thereby
 * increasingly worse) bounds are calculated along a loop in the source code.
 * We prevent this by weakening the bound to a small finite set of bounds when
 * a path follows a second back-edge (we postpone weakening till the second
 * back-edge as a precise bound might require traversing a loop once).
*/

import cpp

private import semmle.code.cpp.ir.IR
private import semmle.code.cpp.controlflow.IRGuards
private import semmle.code.cpp.ir.ValueNumbering
private import RangeUtils
private import SignAnalysis
import Bound

cached private module RangeAnalysisCache {

  cached module RangeAnalysisPublic {
    /**
     * Holds if `b + delta` is a valid bound for `i`.
     * - `upper = true`  : `i <= b + delta`
     * - `upper = false` : `i >= b + delta`
     *
     * The reason for the bound is given by `reason` and may be either a condition
     * or `NoReason` if the bound was proven directly without the use of a bounding
     * condition.
     */
    cached predicate boundedInstruction(Instruction i, Bound b, int delta, boolean upper, Reason reason) {
      boundedInstruction(i, b, delta, upper, _, _, reason)
    }
    
    /**
     * Holds if `b + delta` is a valid bound for `op`.
     * - `upper = true`  : `op <= b + delta`
     * - `upper = false` : `op >= b + delta`
     *
     * The reason for the bound is given by `reason` and may be either a condition
     * or `NoReason` if the bound was proven directly without the use of a bounding
     * condition.
     */
    cached predicate boundedOperand(Operand op, Bound b, int delta, boolean upper, Reason reason) {
      boundedNonPhiOperand(op, b, delta, upper, _, _, reason)
      or
      boundedPhiOperand(op, b, delta, upper, _, _, reason)
    }
  }

  /**
   * Holds if `guard = boundFlowCond(_, _, _, _, _) or guard = eqFlowCond(_, _, _, _, _)`.
   */
  cached predicate possibleReason(IRGuardCondition guard) {
    guard = boundFlowCond(_, _, _, _, _)
    or
    guard = eqFlowCond(_, _, _, _, _)
  }

}
private import RangeAnalysisCache
import RangeAnalysisPublic

/**
 * Gets a condition that tests whether `op` equals `bound + delta`.
 *
 * If the condition evaluates to `testIsTrue`:
 * - `isEq = true`  : `i == bound + delta`
 * - `isEq = false` : `i != bound + delta`
 */
private IRGuardCondition eqFlowCond(Operand op, Operand bound, int delta,
  boolean isEq, boolean testIsTrue)
{
  exists(Operand compared |
    result.ensuresEq(compared, bound, delta, op.getInstruction().getBlock(), isEq) and
    result.controls(bound.getInstruction().getBlock(), testIsTrue) and
    valueNumber(compared.getDefinitionInstruction()) = valueNumber (op.getDefinitionInstruction())
  )
}

/**
 * Holds if `op1 + delta` is a valid bound for `op2`.
 * - `upper = true`  : `op2 <= op1 + delta`
 * - `upper = false` : `op2 >= op1 + delta`
 */
private predicate boundFlowStepSsa(
  NonPhiOperand op2, Operand op1, int delta, boolean upper, Reason reason
) {
  /*op2.getDefinitionInstruction().getAnOperand().(CopySourceOperand) = op1 and
  (upper = true or upper = false) and
  reason = TNoReason() and
  delta = 0
  or*/
  exists(IRGuardCondition guard |
    guard = boundFlowCond(op2, op1, delta, upper, _) and
    reason = TCondReason(guard)
  )
}

/**
 * Gets a condition that tests whether `op` is bounded by `bound + delta`.
 *
 * If the condition evaluates to `testIsTrue`:
 * - `upper = true`  : `op <= bound + delta`
 * - `upper = false` : `op >= bound + delta`
 */
private IRGuardCondition boundFlowCond(NonPhiOperand op, NonPhiOperand bound, int delta, boolean upper,
  boolean testIsTrue)
{
  exists(Operand compared |
    result.comparesLt(compared, bound, delta, upper, testIsTrue) and
    result.controls(op.getInstruction().getBlock(), testIsTrue) and
    valueNumber(compared.getDefinitionInstruction()) = valueNumber(op.getDefinitionInstruction())
  )
  // TODO: strengthening through modulus library
}

/**
 * Gets a condition that tests whether `op` is bounded by `bound + delta`.
 * 
 * - `upper = true`  : `op <= bound + delta`
 * - `upper = false` : `op >= bound + delta`
 */
private IRGuardCondition boundFlowCondPhi(PhiOperand op, NonPhiOperand bound, int delta, boolean upper,
  boolean testIsTrue)
{
  exists(Operand compared |
    result.comparesLt(compared, bound, delta, upper, testIsTrue) and
    result.controlsEdgeDirectly(op.getPredecessorBlock().getLastInstruction(), op.getInstruction().getBlock(), testIsTrue) and
    valueNumber(compared.getDefinitionInstruction()) = valueNumber (op.getDefinitionInstruction())
  )
  or
  exists(Operand compared |
    result.comparesLt(compared, bound, delta, upper, testIsTrue) and
    result.controls(op.getPredecessorBlock(), testIsTrue) and
    valueNumber(compared.getDefinitionInstruction()) = valueNumber (op.getDefinitionInstruction())
  )
  // TODO: strengthening through modulus library
}

private newtype TReason =
  TNoReason() or
  TCondReason(IRGuardCondition guard) { possibleReason(guard) }

/**
 * A reason for an inferred bound. This can either be `CondReason` if the bound
 * is due to a specific condition, or `NoReason` if the bound is inferred
 * without going through a bounding condition.
 */
abstract class Reason extends TReason {
  abstract string toString();
}
class NoReason extends Reason, TNoReason {
  override string toString() { result = "NoReason" }
}
class CondReason extends Reason, TCondReason {
  IRGuardCondition getCond() { this = TCondReason(result) }
  override string toString() { result = getCond().toString() }
}

/**
 * Holds if a cast from `fromtyp` to `totyp` can be ignored for the purpose of
 * range analysis.
 */
private predicate safeCast(IntegralType fromtyp, IntegralType totyp) {
  fromtyp.getSize() < totyp.getSize() and
  (
    fromtyp.isUnsigned()
    or
    totyp.isSigned()
  ) or
  fromtyp.getSize() <= totyp.getSize() and
  (
    fromtyp.isSigned() and
    totyp.isSigned()
    or
    fromtyp.isUnsigned() and
    totyp.isUnsigned()
  )
  // TODO: infer safety using sign analysis?
}

private class SafeCastInstruction extends ConvertInstruction {
  SafeCastInstruction() {
    safeCast(getResultType(), getOperand().getResultType())
  }
}

/**
 * Holds if `typ` is a small integral type with the given lower and upper bounds.
 */
private predicate typeBound(IntegralType typ, int lowerbound, int upperbound) {
  typ.isSigned() and typ.getSize() = 1 and lowerbound = -128 and upperbound = 127
  or
  typ.isUnsigned() and typ.getSize() = 1 and lowerbound = 0 and upperbound = 255
  or
  typ.isSigned() and typ.getSize() = 2 and lowerbound = -32768 and upperbound = 32767
  or
  typ.isUnsigned() and typ.getSize() = 2 and lowerbound = 0 and upperbound = 65535
}

/**
 * A cast to a small integral type that may overflow or underflow.
 */
private class NarrowingCastInstruction extends ConvertInstruction {
  NarrowingCastInstruction() {
    not this instanceof SafeCastInstruction and
    typeBound(getResultType(), _, _)
  }
  /** Gets the lower bound of the resulting type. */
  int getLowerBound() { typeBound(getResultType(), result, _) }
  /** Gets the upper bound of the resulting type. */
  int getUpperBound() { typeBound(getResultType(), _, result) }
}

/**
 * Holds if `op + delta` is a valid bound for `i`.
 * - `upper = true`  : `i <= op + delta`
 * - `upper = false` : `i >= op + delta`
 */
private predicate boundFlowStep(Instruction i, Operand op, int delta, boolean upper) {
  valueFlowStep(i, op, delta) and
  (upper = true or upper = false)
  or
  i.(SafeCastInstruction).getAnOperand() = op and
  delta = 0 and
  (upper = true or upper = false)
  or
  exists(Operand x |
    i.(AddInstruction).getAnOperand() = op and
    i.(AddInstruction).getAnOperand() = x and
    op != x
    |
    not exists(getValue(getConstantValue(op.getInstruction()))) and
    not exists(getValue(getConstantValue(x.getInstruction()))) and
    if(strictlyPositive(x))
    then (
      upper = false and delta = 1
    ) else
      if positive(x)
      then (
        upper = false and delta = 0
      ) else
        if strictlyNegative(x)
        then (
          upper = true and delta = -1
        ) else if negative(x) then (upper = true and delta = 0) else none()
  )
  or
  exists(Operand x |
    exists(SubInstruction sub |
      i = sub and
      sub.getAnOperand().(LeftOperand) = op and
      sub.getAnOperand().(RightOperand) = x
    )
  |
    // `x` with constant value is covered by valueFlowStep
    not exists(getValue(getConstantValue(x.getInstruction()))) and
    if strictlyPositive(x)
    then (
      upper = true and delta = -1
    ) else
      if positive(x)
      then (
        upper = true and delta = 0
      ) else
        if strictlyNegative(x)
        then (
          upper = false and delta = 1
        ) else if negative(x) then (upper = false and delta = 0) else none()
  )
  or
  i.(RemInstruction).getAnOperand().(RightOperand) = op and positive(op) and delta = -1 and upper = true
  or
  i.(RemInstruction).getAnOperand().(LeftOperand) = op and positive(op) and delta = 0 and upper = true
  or
  i.(BitAndInstruction).getAnOperand() = op and positive(op) and delta = 0 and upper = true
  or
  i.(BitOrInstruction).getAnOperand() = op and positiveInstruction(i) and delta = 0 and upper = false
  // TODO: min, max, rand
}

private predicate boundFlowStepMul(Instruction i1, Operand op, int factor) {
  exists(Instruction c, int k | k = getValue(getConstantValue(c)) and k > 0 |
    i1.(MulInstruction).hasOperands(op, c.getAUse()) and factor = k
    or
    exists(ShiftLeftInstruction i |
      i = i1 and i.getAnOperand().(LeftOperand) = op and i.getAnOperand().(RightOperand) = c.getAUse() and factor = 2.pow(k)
    )
  )
}

private predicate boundFlowStepDiv(Instruction i1, Operand op, int factor) {
  exists(Instruction c, int k | k = getValue(getConstantValue(c)) and k > 0 |
    exists(DivInstruction i |
      i = i1 and i.getAnOperand().(LeftOperand) = op and i.getRightOperand() = c and factor = k
    )
    or
    exists(ShiftRightInstruction i |
      i = i1 and i.getAnOperand().(LeftOperand) = op and i.getRightOperand() = c and factor = 2.pow(k)
    )
  )
}

/**
 * Holds if `b` is a valid bound for `op`
 */
pragma[noinline]
private predicate boundedNonPhiOperand(NonPhiOperand op, Bound b, int delta, boolean upper,
  boolean fromBackEdge, int origdelta, Reason reason
) {
  exists(NonPhiOperand op2, int d1, int d2 |
    boundFlowStepSsa(op, op2, d1, upper, reason) and
    boundedNonPhiOperand(op2, b, d2, upper, fromBackEdge, origdelta, _) and
    delta = d1 + d2
  )
  or
  boundedInstruction(op.getDefinitionInstruction(), b, delta, upper, fromBackEdge, origdelta, reason)
  or
  exists(int d, Reason r1, Reason r2 |
    boundedInstruction(op.getDefinitionInstruction(), b, d, upper, fromBackEdge, origdelta, r2)
  |
    unequalOperand(op, b, d, r1) and
    (
      upper = true and delta = d - 1
      or upper = false and delta = d + 1
    ) and
    (
      reason = r1
      or
      reason = r2 and not r2 instanceof NoReason
    )
  )
}

/**
 * Holds if `op1 + delta` is a valid bound for `op2`.
 * - `upper = true`  : `op2 <= op1 + delta`
 * - `upper = false` : `op2 >= op1 + delta`
 */
private predicate boundFlowStepPhi(
  PhiOperand op2, Operand op1, int delta, boolean upper, Reason reason
) {
  op2.getDefinitionInstruction().getAnOperand().(CopySourceOperand) = op1 and
  (upper = true or upper = false) and
  reason = TNoReason() and
  delta = 0
  or
  exists(IRGuardCondition guard |
    guard = boundFlowCondPhi(op2, op1, delta, upper, _) and
    reason = TCondReason(guard)
  )
}


private predicate boundedPhiOperand(
  PhiOperand op, Bound b, int delta, boolean upper, boolean fromBackEdge, int origdelta,
  Reason reason
) {
  exists(NonPhiOperand op2, int d1, int d2, Reason r1, Reason r2 |
    boundFlowStepPhi(op, op2, d1, upper, r1) and
    boundedNonPhiOperand(op2, b, d2, upper, fromBackEdge, origdelta, r2) and
    delta = d1 + d2 and
    (if r1 instanceof NoReason then reason = r2 else reason = r1)
  )
  or
  boundedInstruction(op.getDefinitionInstruction(), b, delta, upper, fromBackEdge, origdelta, reason)
  or
  exists(int d, Reason r1, Reason r2 |
    boundedInstruction(op.getDefinitionInstruction(), b, d, upper, fromBackEdge, origdelta, r2)
  |
    unequalOperand(op, b, d, r1) and
    (
      upper = true and delta = d - 1
      or upper = false and delta = d + 1
    ) and
    (
      reason = r1
      or
      reason = r2 and not r2 instanceof NoReason
    )
  )
}

/**
 * Holds if `op != b + delta` at `pos`.
 */
private predicate unequalOperand(Operand op, Bound b, int delta, Reason reason) {
  // TODO: implement this
  none()
}

private predicate boundedPhiCandValidForEdge(
  PhiInstruction phi, Bound b, int delta, boolean upper, boolean fromBackEdge, int origdelta,
  Reason reason, PhiOperand op
) {
  boundedPhiCand(phi, upper, b, delta, fromBackEdge, origdelta, reason) and
  (
    exists(int d | boundedPhiInp1(phi, op, b, d, upper) | upper = true and d <= delta)
    or
    exists(int d | boundedPhiInp1(phi, op, b, d, upper) | upper = false and d >= delta)
    or
    selfBoundedPhiInp(phi, op, upper)
  )
}

/** Weakens a delta to lie in the range `[-1..1]`. */
bindingset[delta, upper]
private int weakenDelta(boolean upper, int delta) {
  delta in [-1 .. 1] and result = delta
  or
  upper = true and result = -1 and delta < -1
  or
  upper = false and result = 1 and delta > 1
}

private predicate boundedPhiInp(
  PhiInstruction phi, PhiOperand op, Bound b, int delta, boolean upper, boolean fromBackEdge,
  int origdelta, Reason reason 
) {
  phi.getAnOperand() = op and
  exists(int d, boolean fromBackEdge0 |
    boundedInstruction(op.getDefinitionInstruction(), b, d, upper, fromBackEdge0, origdelta, reason)
    or
    boundedPhiOperand(op, b, d, upper, fromBackEdge0, origdelta, reason)
    or
    b.(InstructionBound).getInstruction() = op.getDefinitionInstruction() and
    d = 0 and
    (upper = true or upper = false) and
    fromBackEdge0 = false and
    origdelta = 0 and
    reason = TNoReason()
  |
    if backEdge(phi, op)
    then
      fromBackEdge = true and
      (
        fromBackEdge0 = true and delta = weakenDelta(upper, d - origdelta) + origdelta
        or
        fromBackEdge0 = false and delta = d
      )
    else (
      delta = d and fromBackEdge = fromBackEdge0
    )
  )
}

pragma[noinline]
private predicate boundedPhiInp1(
  PhiInstruction phi, PhiOperand op, Bound b, int delta, boolean upper
) {
  boundedPhiInp(phi, op, b, delta, upper, _, _, _)
}

private predicate selfBoundedPhiInp(PhiInstruction phi, PhiOperand op, boolean upper) {
  exists(int d, InstructionBound phibound |
    phibound.getInstruction() = phi and
    boundedPhiInp(phi, op, phibound, d, upper, _, _, _) and
    (
      upper = true and d <= 0
      or
      upper = false and d >= 0
    )
  )
}

pragma[noinline]
private predicate boundedPhiCand(
  PhiInstruction phi, boolean upper, Bound b, int delta, boolean fromBackEdge, int origdelta,
  Reason reason
) {
  exists(PhiOperand op |
    boundedPhiInp(phi, op, b, delta, upper, fromBackEdge, origdelta, reason)
  )
}

/**
 * Holds if the value being cast has an upper (for `upper = true`) or lower
 * (for `upper = false`) bound within the bounds of the resulting type.
 * For `upper = true` this means that the cast will not overflow and for
 * `upper = false` this means that the cast will not underflow.
 */
private predicate safeNarrowingCast(NarrowingCastInstruction cast, boolean upper) {
  exists(int bound | boundedNonPhiOperand(cast.getAnOperand(), any(ZeroBound zb), bound, upper, _, _, _) |
    upper = true and bound <= cast.getUpperBound()
    or
    upper = false and bound >= cast.getLowerBound()
  )
}

pragma[noinline]
private predicate boundedCastExpr(
  NarrowingCastInstruction cast, Bound b, int delta, boolean upper, boolean fromBackEdge, int origdelta,
  Reason reason
) {
  boundedNonPhiOperand(cast.getAnOperand(), b, delta, upper, fromBackEdge, origdelta, reason)
}
/**
 * Holds if `b + delta` is a valid bound for `i`.
 * - `upper = true`  : `i <= b + delta`
 * - `upper = false` : `i >= b + delta`
 */
private predicate boundedInstruction(
  Instruction i, Bound b, int delta, boolean upper, boolean fromBackEdge, int origdelta, Reason reason
) {
  i instanceof PhiInstruction and
  forex(PhiOperand op | op = i.getAnOperand() |
    boundedPhiCandValidForEdge(i, b, delta, upper, fromBackEdge, origdelta, reason, op)
  )
  or
  i = b.getInstruction(delta) and
  (upper = true or upper = false) and
  fromBackEdge = false and
  origdelta = delta and
  reason = TNoReason()
  or
  exists(Operand mid, int d1, int d2 |
    boundFlowStep(i, mid, d1, upper) and
    boundedNonPhiOperand(mid, b, d2, upper, fromBackEdge, origdelta, reason) and
    delta = d1 + d2 and
    not exists(getValue(getConstantValue(i)))
  )
  or
  exists(Operand mid, int factor, int d |
    boundFlowStepMul(i, mid, factor) and
    boundedNonPhiOperand(mid, b, d, upper, fromBackEdge, origdelta, reason) and
    b instanceof ZeroBound and
    delta = d*factor and
    not exists(getValue(getConstantValue(i)))
  )
  or
  exists(Operand mid, int factor, int d |
    boundFlowStepDiv(i, mid, factor) and
    boundedNonPhiOperand(mid, b, d, upper, fromBackEdge, origdelta, reason) and
    d >= 0 and
    b instanceof ZeroBound and
    delta = d / factor and
    not exists(getValue(getConstantValue(i)))
  )
  or
  exists(NarrowingCastInstruction cast |
    cast = i and
    safeNarrowingCast(cast, upper.booleanNot()) and
    boundedCastExpr(cast, b, delta, upper, fromBackEdge, origdelta, reason)
  )
}

predicate backEdge(PhiInstruction phi, PhiOperand op) {
  phi.getAnOperand() = op and
  phi.getBlock().dominates(op.getPredecessorBlock())
  // TODO: identify backedges during IR construction
}