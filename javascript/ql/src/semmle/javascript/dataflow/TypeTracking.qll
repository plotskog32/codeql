/**
 * Provides the `TypeTracker` class for tracking types interprocedurally.
 *
 * This provides an alternative to `DataFlow::TrackedNode` and `AbstractValue`
 * for tracking certain types interprocedurally without computing which source
 * a given value came from.
 */

import javascript
private import internal.FlowSteps

private class PropertyName extends string {
  PropertyName() { this = any(DataFlow::PropRef pr).getPropertyName() }
}

private class OptionalPropertyName extends string {
  OptionalPropertyName() { this instanceof PropertyName or this = "" }
}

/**
 * A description of a step on an inter-procedural data flow path.
 */
private newtype TStepSummary =
  LevelStep() or
  CallStep() or
  ReturnStep() or
  StoreStep(PropertyName prop) or
  LoadStep(PropertyName prop)

/**
 * INTERNAL: Use `TypeTracker` or `TypeBackTracker` instead.
 *
 * A description of a step on an inter-procedural data flow path.
 */
class StepSummary extends TStepSummary {
  /** Gets a textual representation of this step summary. */
  string toString() {
    this instanceof LevelStep and result = "level"
    or
    this instanceof CallStep and result = "call"
    or
    this instanceof ReturnStep and result = "return"
    or
    exists(string prop | this = StoreStep(prop) | result = "store " + prop)
    or
    exists(string prop | this = LoadStep(prop) | result = "load" + prop)
  }
}

module StepSummary {
  /**
   * INTERNAL: Use `SourceNode.track()` or `SourceNode.backtrack()` instead.
   */
  predicate step(DataFlow::SourceNode pred, DataFlow::SourceNode succ, StepSummary summary) {
    exists(DataFlow::Node predNode | pred.flowsTo(predNode) |
      // Flow through properties of objects
      propertyFlowStep(predNode, succ) and
      summary = LevelStep()
      or
      // Flow through global variables
      globalFlowStep(predNode, succ) and
      summary = LevelStep()
      or
      // Flow into function
      callStep(predNode, succ) and
      summary = CallStep()
      or
      // Flow out of function
      returnStep(predNode, succ) and
      summary = ReturnStep()
      or
      // Flow through an instance field between members of the same class
      DataFlow::localFieldStep(predNode, succ) and
      summary = LevelStep()
      or
      exists(string prop |
        basicStoreStep(predNode, succ, prop) and
        summary = StoreStep(prop)
        or
        loadStep(predNode, succ, prop) and
        summary = LoadStep(prop)
      )
    )
  }
}

private newtype TTypeTracker = MkTypeTracker(Boolean hasCall, OptionalPropertyName prop)

/**
 * EXPERIMENTAL.
 *
 * Summary of the steps needed to track a value to a given dataflow node.
 *
 * This can be used to track objects that implement a certain API in order to
 * recognize calls to that API. Note that type-tracking does not provide a
 * source/sink relation, that is, it may determine that a node has a given type,
 * but it won't determine where that type came from.
 *
 * It is recommended that all uses of this type is written on the following form,
 * for tracking some type `myType`:
 * ```
 * DataFlow::SourceNode myType(DataFlow::TypeTracker t) {
 *   t.start() and
 *   result = < source of myType >
 *   or
 *   exists (DataFlow::TypeTracker t2 |
 *     result = myType(t2).track(t2, t)
 *   )
 * }
 *
 * DataFlow::SourceNode myType() { result = myType(DataFlow::TypeTracker::end()) }
 * ```
 *
 * To track values backwards, which can be useful for tracking
 * the type of a callback, use the `TypeBackTracker` class instead.
 */
class TypeTracker extends TTypeTracker {
  Boolean hasCall;

  string prop;

  TypeTracker() { this = MkTypeTracker(hasCall, prop) }

  /** Gets the summary resulting from appending `step` to this type-tracking summary. */
  TypeTracker append(StepSummary step) {
    step = LevelStep() and result = this
    or
    step = CallStep() and result = MkTypeTracker(true, prop)
    or
    step = ReturnStep() and hasCall = false and result = this
    or
    step = LoadStep(prop) and result = MkTypeTracker(hasCall, "")
    or
    exists(string p | step = StoreStep(p) and prop = "" and result = MkTypeTracker(hasCall, p))
  }

  /** Gets a textual representation of this summary. */
  string toString() {
    exists(string withCall, string withProp |
      (if hasCall = true then withCall = "with" else withCall = "without") and
      (if prop != "" then withProp = " with property " + prop else withProp = "") and
      result = "type tracker " + withCall + " call steps" + withProp
    )
  }

  /**
   * Holds if this is the starting point of type tracking.
   */
  predicate start() { hasCall = false and prop = "" }

  /**
   * Holds if this is the end point of type tracking.
   */
  predicate end() { prop = "" }

  /**
   * INTERNAL. DO NOT USE.
   *
   * Holds if this type has been tracked into a call.
   */
  boolean hasCall() { result = hasCall }

  /**
   * Gets a type tracker that starts where this one has left off to allow continued
   * tracking.
   *
   * This predicate is only defined if the type has not been tracked into a property.
   */
  TypeTracker continue() { prop = "" and result = this }
}

module TypeTracker {
  TypeTracker end() { result.end() }
}

private newtype TTypeBackTracker = MkTypeBackTracker(Boolean hasReturn, OptionalPropertyName prop)

/**
 * EXPERIMENTAL.
 *
 * Summary of the steps needed to back-track a use of a value to a given dataflow node.
 *
 * This can be used to track callbacks that are passed to a certian API call, and are
 * therefore expected to called with a certain type of value.
 *
 * Note that type back-tracking does not provide a source/sink relation, that is,
 * it may determine that a node will be used in an API call somwwhere, but it won't
 * determine exactly where that use was, or the path that led to the use.
 *
 * It is recommended that all uses of this type is written on the following form,
 * for back-tracking some callback type `myCallback`:
 * ```
 * DataFlow::SourceNode myCallback(DataFlow::TypeBackTracker t) {
 *   t.start() and
 *   result = (< some API call >).getArgument(< n >).getALocalSource()
 *   or
 *   exists (DataFlow::TypeBackTracker t2 |
 *     result = myCallback(t2).backtrack(t2, t)
 *   )
 * }
 *
 * DataFlow::SourceNode myCallback() { result = myCallback(DataFlow::TypeBackTracker::end()) }
 * ```
 */
class TypeBackTracker extends TTypeBackTracker {
  Boolean hasReturn;

  string prop;

  TypeBackTracker() { this = MkTypeBackTracker(hasReturn, prop) }

  /** Gets the summary resulting from prepending `step` to this type-tracking summary. */
  TypeBackTracker prepend(StepSummary step) {
    step = LevelStep() and result = this
    or
    step = CallStep() and hasReturn = false and result = this
    or
    step = ReturnStep() and result = MkTypeBackTracker(true, prop)
    or
    exists(string p | step = LoadStep(p) and prop = "" and result = MkTypeBackTracker(hasReturn, p))
    or
    step = StoreStep(prop) and result = MkTypeBackTracker(hasReturn, "")
  }

  /** Gets a textual representation of this summary. */
  string toString() {
    exists(string withReturn, string withProp |
      (if hasReturn = true then withReturn = "with" else withReturn = "without") and
      (if prop != "" then withProp = " with property " + prop else withProp = "") and
      result = "type back-tracker " + withReturn + " return steps" + withProp
    )
  }

  /**
   * Holds if this is the starting point of type tracking.
   */
  predicate start() { hasReturn = false and prop = "" }

  /**
   * Holds if this is the end point of type tracking.
   */
  predicate end() { prop = "" }

  /**
   * INTERNAL. DO NOT USE.
   *
   * Holds if this type has been back-tracked into a call through return edge.
   */
  boolean hasReturn() { result = hasReturn }

  /**
   * Gets a type tracker that starts where this one has left off to allow continued
   * tracking.
   *
   * This predicate is only defined if the type has not been tracked into a property.
   */
  TypeBackTracker continue() { prop = "" and result = this }
}

module TypeBackTracker {
  TypeBackTracker end() { result.end() }
}
