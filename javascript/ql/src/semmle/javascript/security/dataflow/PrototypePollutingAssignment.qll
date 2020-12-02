/**
 * Provides a taint tracking configuration for reasoning about
 * prototype-polluting assignments.
 *
 * Note, for performance reasons: only import this file if
 * `PrototypePollutingAssignment::Configuration` is needed, otherwise
 * `PrototypePollutingAssignmentCustomizations` should be imported instead.
 */

private import javascript
private import semmle.javascript.DynamicPropertyAccess

module PrototypePollutingAssignment {
  private import PrototypePollutingAssignmentCustomizations::PrototypePollutingAssignment

  // Materialize flow labels
  private class ConcreteObjectPrototype extends ObjectPrototype {
    ConcreteObjectPrototype() { this = this }
  }

  /** A taint-tracking configuration for reasoning about prototype-polluting assignments. */
  class Configuration extends TaintTracking::Configuration {
    Configuration() { this = "PrototypePollutingAssignment" }

    override predicate isSource(DataFlow::Node node) { node instanceof Source }

    override predicate isSink(DataFlow::Node node, DataFlow::FlowLabel lbl) {
      node.(Sink).getAFlowLabel() = lbl
    }

    override predicate isSanitizer(DataFlow::Node node) {
      node instanceof Sanitizer
      or
      // Concatenating with a string will in practice prevent the string `__proto__` from arising.
      node instanceof StringOps::ConcatenationRoot
    }

    override predicate isAdditionalFlowStep(
      DataFlow::Node pred, DataFlow::Node succ, DataFlow::FlowLabel inlbl,
      DataFlow::FlowLabel outlbl
    ) {
      // Step from x -> obj[x] while switching to the ObjectPrototype label
      // (If `x` can have the value `__proto__` then the result can be Object.prototype)
      exists(DataFlow::PropRead read |
        pred = read.getPropertyNameExpr().flow() and
        succ = read and
        inlbl.isTaint() and
        outlbl instanceof ObjectPrototype and
        // Exclude cases where the property name came from a property enumeration.
        // If the property name is an own property of the base object, the read won't
        // return Object.prototype.
        not read = any(EnumeratedPropName n).getASourceProp() and
        // Exclude cases where the read has no prototype, or a prototype other than Object.prototype.
        not read = prototypeLessObject().getAPropertyRead() and
        // Exclude cases where this property has just been assigned to
        not read.(DynamicPropRead).hasDominatingAssignment()
      )
      or
      // Same as above, but for property projection.
      exists(PropertyProjection proj |
        proj.isSingletonProjection() and
        pred = proj.getASelector() and
        succ = proj and
        inlbl.isTaint() and
        outlbl instanceof ObjectPrototype
      )
    }

    override predicate isLabeledBarrier(DataFlow::Node node, DataFlow::FlowLabel lbl) {
      super.isLabeledBarrier(node, lbl)
      or
      // Don't propagate the receiver into method calls, as the method lookup will fail on Object.prototype.
      node = any(DataFlow::MethodCallNode m).getReceiver() and
      lbl instanceof ObjectPrototype
    }

    override predicate isSanitizerGuard(TaintTracking::SanitizerGuardNode guard) {
      guard instanceof PropertyPresenceCheck or
      guard instanceof InExprCheck or
      guard instanceof InstanceofCheck or
      guard instanceof IsArrayCheck or
      guard instanceof TypeofCheck or
      guard instanceof EqualityCheck
    }
  }

  /** Gets a data flow node referring to an object created with `Object.create`. */
  DataFlow::SourceNode prototypeLessObject() {
    result = prototypeLessObject(DataFlow::TypeTracker::end())
  }

  private DataFlow::SourceNode prototypeLessObject(DataFlow::TypeTracker t) {
    t.start() and
    // We assume the argument to Object.create is not Object.prototype, since most
    // users wouldn't bother to call Object.create in that case.
    result = DataFlow::globalVarRef("Object").getAMemberCall("create")
    or
    // Allow use of AdditionalFlowSteps and AdditionalTaintSteps to track a bit further
    exists(DataFlow::Node mid |
      prototypeLessObject(t.continue()).flowsTo(mid) and
      any(DataFlow::AdditionalFlowStep s).step(mid, result)
    )
    or
    exists(DataFlow::TypeTracker t2 | result = prototypeLessObject(t2).track(t2, t))
  }

  /** Holds if `Object.prototype` has a member named `prop`. */
  private predicate isPropertyPresentOnObjectPrototype(string prop) {
    exists(ExternalInstanceMemberDecl decl |
      decl.getBaseName() = "Object" and
      decl.getName() = prop
    )
  }

  /** A check of form `e.prop` where `prop` is not present on `Object.prototype`. */
  private class PropertyPresenceCheck extends TaintTracking::LabeledSanitizerGuardNode,
    DataFlow::ValueNode {
    override PropAccess astNode;

    PropertyPresenceCheck() { not isPropertyPresentOnObjectPrototype(astNode.getPropertyName()) }

    override predicate sanitizes(boolean outcome, Expr e, DataFlow::FlowLabel label) {
      e = astNode.getBase() and
      outcome = true and
      label instanceof ObjectPrototype
    }
  }

  /** A check of form `"prop" in e` where `prop` is not present on `Object.prototype`. */
  private class InExprCheck extends TaintTracking::LabeledSanitizerGuardNode, DataFlow::ValueNode {
    override InExpr astNode;

    InExprCheck() {
      not isPropertyPresentOnObjectPrototype(astNode.getLeftOperand().getStringValue())
    }

    override predicate sanitizes(boolean outcome, Expr e, DataFlow::FlowLabel label) {
      e = astNode.getRightOperand() and
      outcome = true and
      label instanceof ObjectPrototype
    }
  }

  /** A check of form `e instanceof X`, which is always false for `Object.prototype`. */
  private class InstanceofCheck extends TaintTracking::LabeledSanitizerGuardNode,
    DataFlow::ValueNode {
    override InstanceofExpr astNode;

    override predicate sanitizes(boolean outcome, Expr e, DataFlow::FlowLabel label) {
      e = astNode.getLeftOperand() and
      outcome = true and
      label instanceof ObjectPrototype
    }
  }

  /** A check of form `typeof e === "string"`. */
  private class TypeofCheck extends TaintTracking::LabeledSanitizerGuardNode, DataFlow::ValueNode {
    override EqualityTest astNode;
    Expr operand;
    string value;

    TypeofCheck() {
      astNode.getLeftOperand().(TypeofExpr).getOperand() = operand and
      astNode.getRightOperand().getStringValue() = value
    }

    override predicate sanitizes(boolean outcome, Expr e, DataFlow::FlowLabel label) {
      (
        value = "object" and outcome = false
        or
        value != "object" and outcome = true
      ) and
      e = operand and
      label instanceof ObjectPrototype
    }
  }

  /** A call to `Array.isArray`, which is false for `Object.prototype`. */
  private class IsArrayCheck extends TaintTracking::LabeledSanitizerGuardNode, DataFlow::CallNode {
    IsArrayCheck() { this = DataFlow::globalVarRef("Array").getAMemberCall("isArray") }

    override predicate sanitizes(boolean outcome, Expr e, DataFlow::FlowLabel label) {
      e = getArgument(0).asExpr() and
      outcome = true and
      label instanceof ObjectPrototype
    }
  }

  /**
   * Sanitizer guard of form `x !== "__proto__"`.
   */
  private class EqualityCheck extends TaintTracking::SanitizerGuardNode, DataFlow::ValueNode {
    override EqualityTest astNode;

    EqualityCheck() { astNode.getAnOperand().getStringValue() = "__proto__" }

    override predicate sanitizes(boolean outcome, Expr e) {
      e = astNode.getAnOperand() and
      outcome = astNode.getPolarity().booleanNot()
    }
  }
}
