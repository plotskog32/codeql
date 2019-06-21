/**
 * INTERNAL: Do not use.
 *
 * Provides a simple analysis for identifying calls to callables that will
 * not return.
 */

import csharp
private import cil
private import semmle.code.cil.CallableReturns
private import semmle.code.csharp.ExprOrStmtParent
private import semmle.code.csharp.commons.Assertions
private import semmle.code.csharp.frameworks.System
private import semmle.code.csharp.controlflow.internal.Completion

/** A call that definitely does not return (conservative analysis). */
abstract class NonReturningCall extends Call {
  /** Gets a valid completion for this non-returning call. */
  abstract Completion getACompletion();
}

private class ExitingCall extends NonReturningCall {
  ExitingCall() {
    this.getTarget() instanceof ExitingCallable
    or
    exists(AssertMethod m | m = this.(FailingAssertion).getAssertMethod() |
      not exists(m.getExceptionClass())
    )
  }

  override ExitCompletionDirect getACompletion() { any() }
}

private class ThrowingCall extends NonReturningCall {
  private ThrowCompletionDirect c;

  ThrowingCall() {
    c = this.getTarget().(ThrowingCallable).getACallCompletion()
    or
    exists(AssertMethod m | m = this.(FailingAssertion).getAssertMethod() |
      c.getExceptionClass() = m.getExceptionClass()
    )
    or
    exists(CIL::Method m, CIL::Type ex |
      this.getTarget().matchesHandle(m) and
      alwaysThrowsException(m, ex) and
      c.getExceptionClass().matchesHandle(ex) and
      not m.isVirtual()
    )
  }

  override ThrowCompletionDirect getACompletion() { result = c }
}

abstract private class NonReturningCallable extends Callable {
  NonReturningCallable() {
    not exists(ReturnStmt ret | ret.getEnclosingCallable() = this) and
    not hasAccessorAutoImplementation(this, _) and
    not exists(Virtualizable v | v.isOverridableOrImplementable() |
      v = this or
      v = this.(Accessor).getDeclaration()
    )
  }
}

abstract private class ExitingCallable extends NonReturningCallable { }

private class DirectlyExitingCallable extends ExitingCallable {
  DirectlyExitingCallable() {
    this = any(Method m |
        m.hasQualifiedName("System.Environment", "Exit") or
        m.hasQualifiedName("System.Windows.Forms.Application", "Exit")
      )
  }
}

private class IndirectlyExitingCallable extends ExitingCallable {
  IndirectlyExitingCallable() {
    forex(ControlFlowElement body | body = this.getABody() | body = getAnExitingElement())
  }
}

private ControlFlowElement getAnExitingElement() {
  result instanceof ExitingCall
  or
  result = getAnExitingStmt()
}

private Stmt getAnExitingStmt() {
  result.(ExprStmt).getExpr() = getAnExitingElement()
  or
  result.(BlockStmt).getFirstStmt() = getAnExitingElement()
  or
  exists(IfStmt ifStmt |
    result = ifStmt and
    ifStmt.getThen() = getAnExitingElement() and
    ifStmt.getElse() = getAnExitingElement()
  )
}

private class ThrowingCallable extends NonReturningCallable {
  ThrowingCallable() {
    forex(ControlFlowElement body | body = this.getABody() | body = getAThrowingElement(_))
  }

  /** Gets a valid completion for a call to this throwing callable. */
  ThrowCompletionDirect getACallCompletion() { this.getABody() = getAThrowingElement(result) }
}

private predicate directlyThrows(ThrowElement te, ThrowCompletion c) {
  c.getExceptionClass() = te.getThrownExceptionType() and
  // For stub implementations, there may exist proper implementations that are not seen
  // during compilation, so we conservatively rule those out
  not isStub(te)
}

private ControlFlowElement getAThrowingElement(ThrowCompletionDirect c) {
  c = result.(ThrowingCall).getACompletion()
  or
  directlyThrows(result, c)
  or
  result = getAThrowingStmt(c)
}

private Stmt getAThrowingStmt(ThrowCompletionDirect c) {
  directlyThrows(result, c)
  or
  result.(ExprStmt).getExpr() = getAThrowingElement(c)
  or
  result.(BlockStmt).getFirstStmt() = getAThrowingStmt(c)
  or
  exists(IfStmt ifStmt, ThrowCompletionDirect c1, ThrowCompletionDirect c2 |
    result = ifStmt and
    ifStmt.getThen() = getAThrowingStmt(c1) and
    ifStmt.getElse() = getAThrowingStmt(c2)
  |
    c = c1
    or
    c = c2
  )
}

/** Holds if `throw` element `te` indicates a stub implementation. */
private predicate isStub(ThrowElement te) {
  exists(Expr e | e = te.getExpr() |
    e instanceof NullLiteral or
    e.getType() instanceof SystemNotImplementedExceptionClass
  )
}
