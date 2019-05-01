/**
 * Provides classes and predicates for representing completions.
 */

/*
 * A completion represents how a statement or expression terminates.
 *
 * There are five kinds of completions: normal completion,
 * `return` completion, `break` completion,
 * `continue` completion, and `throw` completion.
 *
 * Normal completions are further subdivided into boolean completions and all
 * other normal completions. A boolean completion adds the information that the
 * cfg node terminated with the given boolean value due to a subexpression
 * terminating with the other given boolean value. This is only
 * relevant for conditional contexts in which the value controls the
 * control-flow successor.
 */

import java

/**
 * A label of a `LabeledStmt`.
 */
newtype Label = MkLabel(string l) { exists(LabeledStmt lbl | l = lbl.getLabel()) }

/**
 * Either a `Label` or nothing.
 */
newtype MaybeLabel =
  JustLabel(Label l) or
  NoLabel()

/**
 * A completion of a statement or an expression.
 */
newtype Completion =
  /**
   * The statement or expression completes normally and continues to the next statement.
   */
  NormalCompletion() or
  /**
   * The statement or expression completes by returning from the function.
   */
  ReturnCompletion() or
  /**
   * The expression completes with value `outerValue` overall and with the last control
   * flow node having value `innerValue`.
   */
  BooleanCompletion(boolean outerValue, boolean innerValue) {
    (outerValue = true or outerValue = false) and
    (innerValue = true or innerValue = false)
  } or
  /**
   * The expression or statement completes via a `break` statement without a value.
   */
  BreakCompletion(MaybeLabel l) or
  /**
   * The expression or statement completes via a value `break` statement.
   */
  ValueBreakCompletion(NormalOrBooleanCompletion c) or
  /**
   * The expression or statement completes via a `continue` statement.
   */
  ContinueCompletion(MaybeLabel l) or
  /**
   * The expression or statement completes by throwing a `ThrowableType`.
   */
  ThrowCompletion(ThrowableType tt)

class NormalOrBooleanCompletion extends Completion {
  NormalOrBooleanCompletion() {
    this instanceof NormalCompletion or this instanceof BooleanCompletion
  }

  string toString() { result = "completion" }
}

ContinueCompletion anonymousContinueCompletion() { result = ContinueCompletion(NoLabel()) }

ContinueCompletion labelledContinueCompletion(Label l) { result = ContinueCompletion(JustLabel(l)) }

BreakCompletion anonymousBreakCompletion() { result = BreakCompletion(NoLabel()) }

BreakCompletion labelledBreakCompletion(Label l) { result = BreakCompletion(JustLabel(l)) }

/** Gets the completion `booleanCompletion(value, value)`. */
Completion basicBooleanCompletion(boolean value) { result = BooleanCompletion(value, value) }
