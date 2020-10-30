/** Provides classes for assertions. */

private import semmle.code.csharp.frameworks.system.Diagnostics
private import semmle.code.csharp.frameworks.system.diagnostics.Contracts
private import semmle.code.csharp.frameworks.test.VisualStudio
private import semmle.code.csharp.frameworks.System
private import ControlFlow
private import ControlFlow::BasicBlocks

private newtype TAssertionFailure =
  TExceptionAssertionFailure(Class c) or
  TExitAssertionFailure()

/** An entity that describes how an assertion may fail. */
class AssertionFailure extends TAssertionFailure {
  /** Holds if this failure describes an exception of type `c`. */
  predicate isException(Class c) { this = TExceptionAssertionFailure(c) }

  /** Holds if this failure describes an exit. */
  predicate isExit() { this = TExitAssertionFailure() }

  /** Gets a textual representation of this element. */
  string toString() {
    exists(Class c |
      this = TExceptionAssertionFailure(c) and
      result = c.toString()
    )
    or
    this = TExitAssertionFailure() and
    result = "exit"
  }
}

/** An assertion method. */
abstract class AssertMethod extends Method {
  /** Gets the index of a parameter being asserted. */
  abstract int getAnAssertionIndex();

  /**
   * DEPRECATED: Use `getAnAssertionIndex()` instead.
   *
   * Gets the index of a parameter being asserted.
   */
  deprecated final int getAssertionIndex() { result = getAnAssertionIndex() }

  /** Gets the parameter at position `i` being asserted. */
  final Parameter getAssertedParameter(int i) {
    result = this.getParameter(i) and
    i = this.getAnAssertionIndex()
  }

  /**
   * DEPRECATED: Use `getAssertedParameter(_)` instead.
   *
   * Gets a parameter being asserted.
   */
  deprecated final Parameter getAssertedParameter() { result = getAssertedParameter(_) }

  /** Gets the failure type if the assertion fails for argument `i`, if any. */
  abstract AssertionFailure getAssertionFailure(int i);

  /**
   * DEPRECATED: Use `getAssertionFailure(_)` instead.
   *
   * Gets the exception being thrown if the assertion fails, if any.
   */
  deprecated final Class getExceptionClass() { this.getAssertionFailure(_).isException(result) }
}

/** A Boolean assertion method. */
abstract class BooleanAssertMethod extends AssertMethod {
  /** Gets the index of a parameter asserted to have value `b`. */
  abstract int getAnAssertionIndex(boolean b);

  override int getAnAssertionIndex() { result = this.getAnAssertionIndex(_) }
}

/** A positive assertion method. */
deprecated class AssertTrueMethod extends AssertMethod {
  private BooleanAssertMethod m;

  AssertTrueMethod() {
    this = m and
    exists(m.getAnAssertionIndex(true))
  }

  final override int getAnAssertionIndex() { result = m.getAnAssertionIndex() }

  final override AssertionFailure getAssertionFailure(int i) { result = m.getAssertionFailure(i) }
}

/** A negated assertion method. */
deprecated class AssertFalseMethod extends AssertMethod {
  private BooleanAssertMethod m;

  AssertFalseMethod() {
    this = m and
    exists(m.getAnAssertionIndex(false))
  }

  final override int getAnAssertionIndex() { result = m.getAnAssertionIndex() }

  final override AssertionFailure getAssertionFailure(int i) { result = m.getAssertionFailure(i) }
}

/** A nullness assertion method. */
abstract class NullnessAssertMethod extends AssertMethod {
  /**
   * Gets the index of a parameter asserted to be `null` (`b = true`)
   * or non-`null` (`b = false`).
   */
  abstract int getAnAssertionIndex(boolean b);

  override int getAnAssertionIndex() { result = this.getAnAssertionIndex(_) }
}

/** A `null` assertion method. */
deprecated class AssertNullMethod extends AssertMethod {
  private NullnessAssertMethod m;

  AssertNullMethod() {
    this = m and
    exists(m.getAnAssertionIndex(true))
  }

  final override int getAnAssertionIndex() { result = m.getAnAssertionIndex() }

  final override AssertionFailure getAssertionFailure(int i) { result = m.getAssertionFailure(i) }
}

/** A non-`null` assertion method. */
deprecated class AssertNonNullMethod extends AssertMethod {
  private NullnessAssertMethod m;

  AssertNonNullMethod() {
    this = m and
    exists(m.getAnAssertionIndex(false))
  }

  final override int getAnAssertionIndex() { result = m.getAnAssertionIndex() }

  final override AssertionFailure getAssertionFailure(int i) { result = m.getAssertionFailure(i) }
}

/** An assertion, that is, a call to an assertion method. */
class Assertion extends MethodCall {
  private AssertMethod target;

  Assertion() { this.getTarget() = target }

  /** Gets the assertion method targeted by this assertion. */
  AssertMethod getAssertMethod() { result = target }

  /** Gets an expression at argument position `i` that this assertion pertains to. */
  Expr getExpr(int i) {
    i = target.getAnAssertionIndex() and
    exists(Parameter p |
      p = target.getParameter(i) and
      result = this.getArgumentForParameter(p)
    )
  }

  /**
   * DEPRECATED: Use `getExpr(_)` instead.
   *
   * Gets an expression that this assertion pertains to.
   */
  deprecated Expr getExpr() { result = this.getExpr(_) }

  /**
   * Holds if basic block `succ` is immediately dominated by this assertion.
   * That is, `succ` can only be reached from the callable entry point by
   * going via *some* basic block `pred` containing this assertion, and `pred`
   * is an immediate predecessor of `succ`.
   *
   * Moreover, this assertion corresponds to multiple control flow nodes,
   * which is why
   *
   * ```ql
   * exists(BasicBlock bb |
   *   bb.getANode() = this.getAControlFlowNode() |
   *   bb.immediatelyDominates(succ)
   * )
   * ```
   *
   * does not work.
   */
  pragma[nomagic]
  deprecated private predicate immediatelyDominatesBlockSplit(BasicBlock succ) {
    // Only calculate dominance by explicit recursion for split nodes;
    // all other nodes can use regular CFG dominance
    this instanceof ControlFlow::Internal::SplitControlFlowElement and
    exists(BasicBlock bb | bb.getANode() = this.getAControlFlowNode() |
      succ = bb.getASuccessor() and
      forall(BasicBlock pred | pred = succ.getAPredecessor() and pred != bb |
        succ.dominates(pred)
        or
        // `pred` might be another split of this element
        pred.getANode().getElement() = this
      )
    )
  }

  pragma[noinline]
  deprecated private predicate strictlyDominatesJoinBlockPredecessor(JoinBlock jb, int i) {
    this.strictlyDominatesSplit(jb.getJoinBlockPredecessor(i))
  }

  deprecated private predicate strictlyDominatesJoinBlockSplit(JoinBlock jb, int i) {
    i = -1 and
    this.strictlyDominatesJoinBlockPredecessor(jb, _)
    or
    this.strictlyDominatesJoinBlockSplit(jb, i - 1) and
    (
      this.strictlyDominatesJoinBlockPredecessor(jb, i)
      or
      this.getAControlFlowNode().getBasicBlock() = jb.getJoinBlockPredecessor(i)
    )
  }

  pragma[nomagic]
  deprecated private predicate strictlyDominatesSplit(BasicBlock bb) {
    this.immediatelyDominatesBlockSplit(bb)
    or
    // Equivalent with
    //
    // ```ql
    // exists(JoinBlockPredecessor pred | pred = bb.getAPredecessor() |
    //   this.strictlyDominatesSplit(pred)
    // ) and
    // forall(JoinBlockPredecessor pred | pred = bb.getAPredecessor() |
    //   this.strictlyDominatesSplit(pred)
    //   or
    //   this.getAControlFlowNode().getBasicBlock() = pred
    // )
    // ```
    //
    // but uses no universal recursion for better performance.
    exists(int last | last = max(int i | exists(bb.(JoinBlock).getJoinBlockPredecessor(i))) |
      this.strictlyDominatesJoinBlockSplit(bb, last)
    )
    or
    not bb instanceof JoinBlock and
    this.strictlyDominatesSplit(bb.getAPredecessor())
  }

  /**
   * DEPRECATED: Use `getExpr().controlsBlock()` instead.
   *
   * Holds if this assertion strictly dominates basic block `bb`. That is, `bb`
   * can only be reached from the callable entry point by going via *some* basic
   * block containing this element.
   *
   * This predicate is different from
   * `this.getAControlFlowNode().getBasicBlock().strictlyDominates(bb)`
   * in that it takes control flow splitting into account.
   */
  pragma[nomagic]
  deprecated predicate strictlyDominates(BasicBlock bb) {
    this.strictlyDominatesSplit(bb)
    or
    this.getAControlFlowNode().getBasicBlock().strictlyDominates(bb)
  }
}

/** A trivially failing assertion, for example `Debug.Assert(false)`. */
class FailingAssertion extends Assertion {
  private int i;

  FailingAssertion() {
    exists(BooleanAssertMethod am, Expr e, boolean b |
      am = this.getAssertMethod() and
      e = this.getExpr(i) and
      i = am.getAnAssertionIndex(b)
    |
      b = true and
      e.getValue() = "false"
      or
      b = false and
      e.getValue() = "true"
    )
  }

  /** Gets the exception being thrown by this failing assertion, if any. */
  AssertionFailure getAssertionFailure() { result = this.getAssertMethod().getAssertionFailure(i) }
}

/**
 * A `System.Diagnostics.Debug` assertion method.
 */
class SystemDiagnosticsDebugAssertTrueMethod extends BooleanAssertMethod {
  SystemDiagnosticsDebugAssertTrueMethod() {
    this = any(SystemDiagnosticsDebugClass c).getAssertMethod()
  }

  override int getAnAssertionIndex(boolean b) { result = 0 and b = true }

  override AssertionFailure getAssertionFailure(int i) {
    // A failing assertion generates a message box, see
    // https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.debug.assert
    i = 0 and result.isExit()
  }
}

/**
 * A `System.Diagnostics.Contracts.Contract` assertion method.
 */
class SystemDiagnosticsContractAssertTrueMethod extends BooleanAssertMethod {
  SystemDiagnosticsContractAssertTrueMethod() {
    exists(SystemDiagnosticsContractsContractClass c |
      this = c.getAnAssertMethod()
      or
      this = c.getAnAssumeMethod()
      or
      this = c.getARequiresMethod()
    )
  }

  override int getAnAssertionIndex(boolean b) { result = 0 and b = true }

  override AssertionFailure getAssertionFailure(int i) {
    // A failing assertion generates a message box, see
    // https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.contracts.contract.assert
    i = 0 and result.isExit()
  }
}

private predicate isDoesNotReturnIfAttributeParameter(Parameter p, boolean value) {
  exists(Attribute a | a = p.getAnAttribute() |
    a.getType() instanceof SystemDiagnosticsCodeAnalysisDoesNotReturnIfAttributeClass and
    a.getConstructorArgument(0).(BoolLiteral).getBoolValue() = value
  )
}

/**
 * A method with a parameter that is annotated with
 * `System.Diagnostics.CodeAnalysis.DoesNotReturnIfAttribute(false)`.
 */
class SystemDiagnosticsCodeAnalysisDoesNotReturnIfAnnotatedAssertTrueMethod extends BooleanAssertMethod {
  private int i_;

  SystemDiagnosticsCodeAnalysisDoesNotReturnIfAnnotatedAssertTrueMethod() {
    isDoesNotReturnIfAttributeParameter(this.getParameter(i_), false)
  }

  override int getAnAssertionIndex(boolean b) { result = i_ and b = true }

  override AssertionFailure getAssertionFailure(int i) {
    i = i_ and result.isException(any(SystemExceptionClass c))
  }
}

/**
 * A method with a parameter that is annotated with
 * `System.Diagnostics.CodeAnalysis.DoesNotReturnIfAttribute(true)`.
 */
class SystemDiagnosticsCodeAnalysisDoesNotReturnIfAnnotatedAssertFalseMethod extends BooleanAssertMethod {
  private int i_;

  SystemDiagnosticsCodeAnalysisDoesNotReturnIfAnnotatedAssertFalseMethod() {
    isDoesNotReturnIfAttributeParameter(this.getParameter(i_), true)
  }

  override int getAnAssertionIndex(boolean b) {
    result = i_ and
    b = false
  }

  override AssertionFailure getAssertionFailure(int i) {
    i = i_ and result.isException(any(SystemExceptionClass c))
  }
}

/** A Visual Studio assertion method. */
class VSTestAssertTrueMethod extends BooleanAssertMethod {
  VSTestAssertTrueMethod() { this = any(VSTestAssertClass c).getIsTrueMethod() }

  override int getAnAssertionIndex(boolean b) { result = 0 and b = true }

  override AssertionFailure getAssertionFailure(int i) {
    i = 0 and result.isException(any(AssertFailedExceptionClass c))
  }
}

/** A Visual Studio negated assertion method. */
class VSTestAssertFalseMethod extends BooleanAssertMethod {
  VSTestAssertFalseMethod() { this = any(VSTestAssertClass c).getIsFalseMethod() }

  override int getAnAssertionIndex(boolean b) { result = 0 and b = false }

  override AssertionFailure getAssertionFailure(int i) {
    i = 0 and result.isException(any(AssertFailedExceptionClass c))
  }
}

/** A Visual Studio `null` assertion method. */
class VSTestAssertNullMethod extends NullnessAssertMethod {
  VSTestAssertNullMethod() { this = any(VSTestAssertClass c).getIsNullMethod() }

  override int getAnAssertionIndex(boolean b) { result = 0 and b = true }

  override AssertionFailure getAssertionFailure(int i) {
    i = 0 and result.isException(any(AssertFailedExceptionClass c))
  }
}

/** A Visual Studio non-`null` assertion method. */
class VSTestAssertNonNullMethod extends NullnessAssertMethod {
  VSTestAssertNonNullMethod() { this = any(VSTestAssertClass c).getIsNotNullMethod() }

  override int getAnAssertionIndex(boolean b) { result = 0 and b = false }

  override AssertionFailure getAssertionFailure(int i) {
    i = 0 and result.isException(any(AssertFailedExceptionClass c))
  }
}

/** An NUnit assertion method. */
abstract class NUnitAssertMethod extends AssertMethod {
  override int getAnAssertionIndex() { result = 0 }

  override AssertionFailure getAssertionFailure(int i) {
    i = 0 and result.isException(any(AssertionExceptionClass c))
  }
}

/** An NUnit assertion method. */
class NUnitAssertTrueMethod extends BooleanAssertMethod, NUnitAssertMethod {
  NUnitAssertTrueMethod() {
    exists(NUnitAssertClass c |
      this = c.getATrueMethod()
      or
      this = c.getAnIsTrueMethod()
      or
      this = c.getAThatMethod() and
      this.getParameter(0).getType() instanceof BoolType
    )
  }

  override int getAnAssertionIndex() { result = NUnitAssertMethod.super.getAnAssertionIndex() }

  override int getAnAssertionIndex(boolean b) { result = this.getAnAssertionIndex() and b = true }
}

/** An NUnit negated assertion method. */
class NUnitAssertFalseMethod extends BooleanAssertMethod, NUnitAssertMethod {
  NUnitAssertFalseMethod() {
    exists(NUnitAssertClass c |
      this = c.getAFalseMethod() or
      this = c.getAnIsFalseMethod()
    )
  }

  override int getAnAssertionIndex() { result = NUnitAssertMethod.super.getAnAssertionIndex() }

  override int getAnAssertionIndex(boolean b) { result = this.getAnAssertionIndex() and b = false }
}

/** An NUnit `null` assertion method. */
class NUnitAssertNullMethod extends NullnessAssertMethod, NUnitAssertMethod {
  NUnitAssertNullMethod() {
    exists(NUnitAssertClass c |
      this = c.getANullMethod() or
      this = c.getAnIsNullMethod()
    )
  }

  override int getAnAssertionIndex() { result = NUnitAssertMethod.super.getAnAssertionIndex() }

  override int getAnAssertionIndex(boolean b) { result = this.getAnAssertionIndex() and b = true }
}

/** An NUnit non-`null` assertion method. */
class NUnitAssertNonNullMethod extends NullnessAssertMethod, NUnitAssertMethod {
  NUnitAssertNonNullMethod() {
    exists(NUnitAssertClass c |
      this = c.getANotNullMethod() or
      this = c.getAnIsNotNullMethod()
    )
  }

  override int getAnAssertionIndex() { result = NUnitAssertMethod.super.getAnAssertionIndex() }

  override int getAnAssertionIndex(boolean b) { result = this.getAnAssertionIndex() and b = false }
}

/** A method that forwards to another assertion method. */
class ForwarderAssertMethod extends AssertMethod {
  private Assertion a;
  private Parameter p;
  private int forwarderIndex;

  ForwarderAssertMethod() {
    p = this.getAParameter() and
    strictcount(AssignableDefinition def | def.getTarget() = p) = 1 and
    forex(ControlFlowElement body | body = this.getBody() |
      bodyAsserts(this, body, a) and
      a.getExpr(forwarderIndex) = p.getAnAccess()
    )
  }

  override int getAnAssertionIndex() { result = p.getPosition() }

  /** Gets the assertion index of the forwarded assertion, for assertion index `i`. */
  int getAForwarderAssertionIndex(int i) { i = p.getPosition() and result = forwarderIndex }

  override AssertionFailure getAssertionFailure(int i) {
    i = p.getPosition() and
    result = this.getUnderlyingAssertMethod().getAssertionFailure(forwarderIndex)
  }

  /** Gets the underlying assertion method that is being forwarded to. */
  AssertMethod getUnderlyingAssertMethod() { result = a.getAssertMethod() }
}

pragma[noinline]
private predicate bodyAsserts(Callable c, ControlFlowElement body, Assertion a) {
  c.getBody() = body and
  body = getAnAssertingElement(a)
}

private ControlFlowElement getAnAssertingElement(Assertion a) {
  result = a
  or
  result = getAnAssertingStmt(a)
}

private Stmt getAnAssertingStmt(Assertion a) {
  result.(ExprStmt).getExpr() = getAnAssertingElement(a)
  or
  result.(BlockStmt).getFirstStmt() = getAnAssertingElement(a)
}

/** A method that forwards to a Boolean assertion method. */
class ForwarderBooleanAssertMethod extends BooleanAssertMethod {
  private ForwarderAssertMethod forwarder;
  private BooleanAssertMethod underlying;

  ForwarderBooleanAssertMethod() {
    forwarder = this and
    underlying = forwarder.getUnderlyingAssertMethod()
  }

  override int getAnAssertionIndex(boolean b) {
    forwarder.getAForwarderAssertionIndex(result) = underlying.getAnAssertionIndex(b)
  }

  override AssertionFailure getAssertionFailure(int i) {
    result = underlying.getAssertionFailure(forwarder.getAForwarderAssertionIndex(i))
  }
}

/** A method that forwards to a positive assertion method. */
deprecated class ForwarderAssertTrueMethod extends ForwarderBooleanAssertMethod {
  ForwarderAssertTrueMethod() { exists(this.getAnAssertionIndex(true)) }
}

/** A method that forwards to a negated assertion method. */
deprecated class ForwarderAssertFalseMethod extends ForwarderBooleanAssertMethod {
  ForwarderAssertFalseMethod() { exists(this.getAnAssertionIndex(false)) }
}

/** A method that forwards to a nullness assertion method. */
class ForwarderNullnessAssertMethod extends NullnessAssertMethod {
  private ForwarderAssertMethod forwarder;
  private NullnessAssertMethod underlying;

  ForwarderNullnessAssertMethod() {
    forwarder = this and
    underlying = forwarder.getUnderlyingAssertMethod()
  }

  override int getAnAssertionIndex(boolean b) {
    forwarder.getAForwarderAssertionIndex(result) = underlying.getAnAssertionIndex(b)
  }

  override AssertionFailure getAssertionFailure(int i) {
    result = underlying.getAssertionFailure(forwarder.getAForwarderAssertionIndex(i))
  }
}

/** A method that forwards to a `null` assertion method. */
deprecated class ForwarderAssertNullMethod extends ForwarderNullnessAssertMethod {
  ForwarderAssertNullMethod() { exists(this.getAnAssertionIndex(true)) }
}

/** A method that forwards to a non-`null` assertion method. */
deprecated class ForwarderAssertNonNullMethod extends ForwarderNullnessAssertMethod {
  ForwarderAssertNonNullMethod() { exists(this.getAnAssertionIndex(false)) }
}

/** Holds if expression `e` appears in an assertion. */
predicate isExprInAssertion(Expr e) { e = any(Assertion a).getExpr(_).getAChildExpr*() }
