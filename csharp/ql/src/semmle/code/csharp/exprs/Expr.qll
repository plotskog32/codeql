/**
 * Provides all expression classes.
 *
 * All expressions have the common base class `Expr`.
 */

import semmle.code.csharp.Location
import semmle.code.csharp.Stmt
import semmle.code.csharp.Callable
import semmle.code.csharp.Type
import Access
import ArithmeticOperation
import Assignment
import BitwiseOperation
import Call
import ComparisonOperation
import Creation
import Dynamic
import Literal
import LogicalOperation
import semmle.code.csharp.controlflow.ControlFlowElement
private import semmle.code.csharp.Enclosing::Internal
private import semmle.code.csharp.frameworks.System
private import dotnet

/**
 * An expression. Either an access (`Access`), a call (`Call`), an object or
 * collection initializer (`ObjectOrCollectionInitializer`), a delegate
 * creation (`DelegateCreation`), an array initializer (`ArrayInitializer`), an
 * array creation (`ArrayCreation`), an anonymous function
 * (`AnonymousFunctionExpr`), a local variable declaration
 * (`LocalVariableDeclExpr`), an operation (`Operation`), a parenthesized
 * expression (`ParenthesizedExpr`), a checked expression (`CheckedExpr`), an
 * unchecked expression (`UncheckedExpr`), an `is` expression (`IsExpr`), an
 * `as` expression (`AsExpr`), a cast (`CastExpr`), a `typeof` expression
 * (`TypeofExpr`), a `default` expression (`DefaultValueExpr`), an `await`
 * expression (`AwaitExpr`), a `nameof` expression (`NameOfExpr`), an
 * interpolated string (`InterpolatedStringExpr`), a qualifiable expression
 * (`QualifiableExpr`), or a literal (`Literal`).
 */
class Expr extends DotNet::Expr, ControlFlowElement, @expr {
  override string toString() { result = "Expression" }

  override Location getALocation() { expr_location(this, result) }

  /** Gets the type of this expression. */
  override Type getType() { expressions(this, _, getTypeRef(result)) }

  /** Gets the value of this expression, if any */
  override string getValue() { expr_value(this, result) }

  /** Holds if this expression has a value. */
  predicate hasValue() { exists(getValue()) }

  /** Gets the enclosing statement of this expression, if any. */
  final Stmt getEnclosingStmt() { enclosingStmt(this, result) }

  /** Gets the enclosing callable of this expression, if any. */
  override Callable getEnclosingCallable() { exprEnclosingCallable(this, result) }

  /**
   * Holds if this expression is generated by the compiler and does not appear
   * explicitly in the source code.
   */
  predicate isImplicit() { expr_compiler_generated(this) }

  /**
   * Gets an expression that is the result of stripping (recursively) all
   * implicit and explicit casts from this expression, if any. For example,
   * the result is `reader` if this expression is either `(IDisposable)reader`
   * or `reader as IDisposable`.
   */
  Expr stripCasts() { result = this }

  /**
   * Gets an expression that is the result of stripping (recursively) all
   * implicit casts from this expression, if any.
   */
  Expr stripImplicitCasts() { result = this }

  /**
   * Gets the explicit parameter name used to pass this expression as an
   * argument for, if any. For example, if this expression is `0` in
   * `M(second: 1, first: 0)` then the result is `"first"`.
   */
  string getExplicitArgumentName() { expr_argument_name(this, result) }

  override Element getParent() { result = ControlFlowElement.super.getParent() }
}

/**
 * An expression whose target may be late bound when using `dynamic`
 * subexpressions. Either a method call (`MethodCall`), an operator call
 * (`OperatorCall`), a constructor call (`ObjectCreation`), a dynamic member
 * access (`DynamicMemberAccess`), or a dynamic element access
 * (`DynamicElementAccess`).
 */
class LateBindableExpr extends Expr, @late_bindable_expr {
  /** Holds if this expression is late bound. */
  predicate isLateBound() {
    exists(getLateBoundTargetName()) or
    isDynamicMemberAccess(this) or
    isDynamicElementAccess(this)
  }

  /** Gets the name of the target that is late bound, if any. */
  string getLateBoundTargetName() { dynamic_member_name(this, result) }
}

private predicate isDynamicMemberAccess(@dynamic_member_access_expr e) { any() }

private predicate isDynamicElementAccess(@dynamic_element_access_expr e) { any() }

/**
 * A local variable declaration, for example `var i = 0`.
 */
class LocalVariableDeclExpr extends Expr, @local_var_decl_expr {
  /** Gets the local variable being declared. */
  LocalVariable getVariable() { localvars(result, _, _, _, _, this) }

  /** Gets the name of the variable being declared. */
  string getName() { result = this.getVariable().getName() }

  /** Gets the initializer expression of this local variable declaration, if any. */
  Expr getInitializer() { result = this.getChild(0) }

  /** Holds if this local variable declaration has an initializer. */
  predicate hasInitializer() { exists(this.getInitializer()) }

  /**
   * Holds if the declared variable is implicitly typed, for example
   * `var x = 0;`.
   */
  predicate isImplicitlyTyped() { this.getVariable().isImplicitlyTyped() }

  override string toString() {
    result = this.getVariable().getType().getName() + " " + this.getName()
  }

  /** Gets the variable access used in this declaration, if any. */
  LocalVariableAccess getAccess() {
    result = this.getChild(1) or
    result = this // `out` argument
  }

  /**
   * Holds if this variable declaration is defined as an `out` argument,
   * for example `M(out int x)`.
   */
  predicate isOutArgument() { expr_argument(this, 2) }
}

/**
 * A local constant declaration, for example `const int i = 0`.
 */
class LocalConstantDeclExpr extends LocalVariableDeclExpr {
  LocalConstantDeclExpr() { super.getVariable() instanceof LocalConstant }

  override LocalConstant getVariable() { localvars(result, _, _, _, _, this) }
}

/**
 * An operation. Either an assignment (`Assignment`), a unary operation
 * (`UnaryOperation`), a binary operation (`BinaryOperation`), or a
 * ternary operation (`TernaryOperation`).
 */
class Operation extends Expr, @op_expr {
  /** Gets the name of the operator in this operation. */
  string getOperator() { none() }

  /** Gets an operand of this operation. */
  Expr getAnOperand() { result = this.getAChild() }
}

/**
 * A unary operation. Either a unary arithemtic operation
 * (`UnaryArithmeticOperation`), a unary bitwise operation
 * (`UnaryBitwiseOperation`), a `sizeof` operation (`SizeofExpr`), a pointer
 * indirection operation (`PointerIndirectionExpr`), an address-of operation
 * (`AddressOfExpr`), or a unary logical operation (`UnaryLogicalOperation`).
 */
class UnaryOperation extends Operation, @un_op {
  /** Gets the operand of this unary operation. */
  Expr getOperand() { result = this.getChild(0) }

  override string toString() { result = this.getOperator() + "..." }
}

/**
 * A binary operation. Either a binary arithemtic operation
 * (`BinaryArithmeticOperation`), a binary bitwise operation
 * (`BinaryBitwiseOperation`), a comparison operation (`ComparisonOperation`),
 * or a binary logical operation (`BinaryLogicalOperation`).
 */
class BinaryOperation extends Operation, @bin_op {
  /** Gets the left operand of this binary operation. */
  Expr getLeftOperand() { result = this.getChild(0) }

  /** Gets the right operand of this binary operation. */
  Expr getRightOperand() { result = this.getChild(1) }

  /** Gets the other operand of this binary operation, given operand `o`. */
  Expr getOtherOperand(Expr o) {
    o = getLeftOperand() and result = getRightOperand()
    or
    o = getRightOperand() and result = getLeftOperand()
  }

  override string getOperator() { none() }

  override string toString() { result = "... " + this.getOperator() + " ..." }
}

/**
 * A ternary operation, that is, a ternary conditional operation
 * (`ConditionalExpr`).
 */
class TernaryOperation extends Operation, @ternary_op { }

/**
 * A parenthesized expression, for example `(2 + 3)` in
 *
 * ```
 * 4 * (2 + 3)
 * ```
 */
class ParenthesizedExpr extends Expr, @par_expr {
  /** Gets the parenthesized expression. */
  Expr getExpr() { result = this.getChild(0) }

  override string toString() { result = "(...)" }
}

/**
 * A checked expression, for example `checked(2147483647 + ten)`.
 */
class CheckedExpr extends Expr, @checked_expr {
  /** Gets the checked expression. */
  Expr getExpr() { result = this.getChild(0) }

  override string toString() { result = "checked (...)" }
}

/**
 * An unchecked expression, for example `unchecked(ConstantMax + 10)`.
 */
class UncheckedExpr extends Expr, @unchecked_expr {
  /** Gets the unchecked expression. */
  Expr getExpr() { result = this.getChild(0) }

  override string toString() { result = "unchecked (...)" }
}

/**
 * An `is` expression.
 * Either an `is` type expression (`IsTypeExpr`) or an `is` constant expression (`IsConstantExpr`).
 */
class IsExpr extends Expr, @is_expr {
  /**
   * Gets the expression being checked, for example `x` in `x is string`.
   */
  Expr getExpr() { result = this.getChild(0) }

  override string toString() { result = "... is ..." }
}

/**
 * An `is` type expression, for example, `x is string` or `x is string s`.
 */
class IsTypeExpr extends IsExpr {
  TypeAccess typeAccess;

  IsTypeExpr() { typeAccess = this.getChild(1) }

  /**
   * Gets the type being accessed in this `is` expression, for example `string`
   * in `x is string`.
   */
  Type getCheckedType() { result = typeAccess.getTarget() }

  /**
   * Gets the type access in this `is` expression, for example `string` in
   * `x is string`.
   */
  TypeAccess getTypeAccess() { result = typeAccess }
}

/**
 * An `is` pattern expression, for example `x is string s`.
 */
class IsPatternExpr extends IsTypeExpr {
  LocalVariableDeclExpr typeDecl;

  IsPatternExpr() { typeDecl = this.getChild(2) }

  /**
   * Gets the local variable declaration in this `is` pattern expression.
   * For example `string s` in `x is string s`.
   */
  LocalVariableDeclExpr getVariableDeclExpr() { result = typeDecl }
}

/**
 * An `is` constant expression, for example `x is 5`.
 */
class IsConstantExpr extends IsExpr {
  Expr constant;

  IsConstantExpr() { constant = this.getChild(3) }

  /** Gets the constant expression, for example `5` in `x is 5`. */
  Expr getConstant() { result = constant }

  /** Gets the value of the constant, for example 5 in `x is 5`. */
  string getConstantValue() { result = constant.getValue() }
}

/**
 * A cast. Either an `as` expression (`AsExpr`) or a cast expression (`CastExpr`).
 */
class Cast extends Expr {
  Cast() {
    this instanceof @as_expr or
    this instanceof @cast_expr
  }

  /** Gets the expression being casted. */
  Expr getExpr() { result = this.getChild(0) }

  /** Gets the type access in this cast. */
  TypeAccess getTypeAccess() { result = this.getChild(1) }

  /** Gets the type that the underlying expression is being cast to. */
  Type getTargetType() { result = this.getTypeAccess().getTarget() }

  /** Gets the type of the underlying expression. */
  Type getSourceType() { result = this.getExpr().getType() }

  override Expr stripCasts() { result = this.getExpr().stripCasts() }

  override Expr stripImplicitCasts() {
    if this.isImplicit() then result = this.getExpr().stripImplicitCasts() else result = this
  }
}

/**
 * An implicit cast. For example, the implicit cast from `string` to `object`
 * on line 3 in
 *
 * ```
 * class C {
 *   void M1(object o) { }
 *   void M2(string s) => M1(s);
 * }
 * ```
 */
class ImplicitCast extends Cast {
  ImplicitCast() { this.isImplicit() }
}

/**
 * An explicit cast. For example, the explicit cast from `object` to `string`
 * on line 2 in
 *
 * ```
 * class C {
 *   string M1(object o) => (string) o;
 * }
 * ```
 */
class ExplicitCast extends Cast {
  ExplicitCast() { not this instanceof ImplicitCast }
}

/**
 * An `as` expression, for example `x as string`.
 */
class AsExpr extends Cast, @as_expr {
  override string toString() { result = "... as ..." }
}

/**
 * A cast expression, for example `(string) x`.
 */
class CastExpr extends Cast, @cast_expr {
  override string toString() { result = "(...) ..." }
}

/**
 * A `typeof` expression, for example `typeof(string)`.
 */
class TypeofExpr extends Expr, @typeof_expr {
  /**
   * Gets the type access in this `typeof` expression, for example `string` in
   * `typeof(string)`.
   */
  TypeAccess getTypeAccess() { result = this.getChild(0) }

  override string toString() { result = "typeof(...)" }
}

/**
 * A `default` expression, for example `default` or `default(string)`.
 */
class DefaultValueExpr extends Expr, @default_expr {
  /**
   * Gets the type access in this `default` expression, for example `string` in
   * `default(string)`, if any.
   */
  TypeAccess getTypeAccess() { result = this.getChild(0) }

  override string toString() {
    if exists(getTypeAccess()) then result = "default(...)" else result = "default"
  }
}

/**
 * A `sizeof` expression, for example `sizeof(int)`.
 */
class SizeofExpr extends UnaryOperation, @sizeof_expr {
  /**
   * Gets the type access in this `sizeof` expression, for example `int` in
   * `sizeof(int)`.
   */
  TypeAccess getTypeAccess() { result = getOperand() }

  override string getOperator() { result = "sizeof(..)" }

  override string toString() { result = "sizeof(..)" }
}

/**
 * A pointer indirection operation, for example `*pn` on line 7,
 * `pa->M()` on line 13, and `cp[1]` on line 18 in
 *
 * ```
 * struct A {
 *   public void M() { }
 *
 *   unsafe int DirectDerefence() {
 *     int n = 10;
 *     int *pn = &n;
 *     return *pn;
 *   }
 *
 *   unsafe void MemberDereference() {
 *     A a = new A();
 *     A *pa = &a;
 *     pa->M();
 *   }
 *
 *   unsafe void ArrayDerefence() {
 *     char* cp = stackalloc char[10];
 *     cp[1] = 'a';
 *   }
 * }
 * ```
 *
 * There are three syntactic forms of indirection through a pointer:
 *
 * - Line 7: A direct dereference, `*pn`.
 * - Line 13: A dereference and member access, `pa->M()`.
 * - Line 18: An array-like dereference, `cp[1]` (this is actually computed as
 *  `*(cp + 1)`).
 */
class PointerIndirectionExpr extends UnaryOperation, @pointer_indirection_expr {
  override string getOperator() { result = "*" }
}

/**
 * An address-of expression, for example `&n` on line 4 in
 *
 * ```
 * class A {
 *   unsafe int DirectDerefence() {
 *     int n = 10;
 *     int *pn = &n;
 *     return *pn;
 *   }
 * }
 * ```
 */
class AddressOfExpr extends UnaryOperation, @address_of_expr {
  override string getOperator() { result = "&" }
}

/**
 * An `await` expression, for example `await AsyncMethodThatReturnsTask()`.
 */
class AwaitExpr extends Expr, @await_expr {
  /** Gets the expression being awaited. */
  Expr getExpr() { result = getChild(0) }

  override string toString() { result = "await ..." }
}

/**
 * A `nameof` expression, for example `nameof(s)` on line 3 in
 *
 * ```
 * void M(string s) {
 *   if (s == null)
 *     throw new ArgumentNullException(nameof(s));
 *   ...
 * }
 * ```
 */
class NameOfExpr extends Expr, @nameof_expr {
  override string toString() { result = "nameof(...)" }

  /**
   * Gets the access in this `nameof` expression, for example `x.F` in
   * `nameof(x.F)`.
   */
  Access getAccess() { result = this.getChild(0) }
}

/**
 * An interpolated string, for example `$"Hello, {name}!"` on line 2 in
 *
 * ```
 * void Hello(string name) {
 *   Console.WriteLine($"Hello, {name}!");
 * }
 * ```
 */
class InterpolatedStringExpr extends Expr, @interpolated_string_expr {
  override string toString() { result = "$\"...\"" }

  /**
   * Gets the insert at index `i` in this interpolated string, if any. For
   * example, the insert at index `i = 1` is `name` in `$"Hello, {name}!"`.
   * Note that there is no insert at index `i = 0`, but instead a text
   * element (`getText(0)` gets the text).
   */
  Expr getInsert(int i) {
    result = getChild(i) and
    not result instanceof StringLiteral
  }

  /**
   * Gets the text element at index `i` in this interpolated string, if any.
   * For example, the text element at index `i = 2` is `"!"` in
   * `$"Hello, {name}!"`. Note that there is no text element at index `i = 1`,
   * but instead an insert (`getInsert(1)` gets the insert).
   */
  StringLiteral getText(int i) { result = getChild(i) }

  /** Gets an insert in this interpolated string. */
  Expr getAnInsert() { result = getInsert(_) }

  /** Gets a text element in this interpolated string. */
  StringLiteral getAText() { result = getText(_) }
}

/**
 * A `throw` element. Either a `throw` expression (`ThrowExpr`)
 * or a `throw` statement (`ThrowStmt`).
 */
class ThrowElement extends ControlFlowElement, DotNet::Throw, @throw_element {
  /**
   * Gets the expression of the exception being thrown, if any.
   *
   * For example, `new Exception("Syntax error")` in `throw new Exception("Syntax error");`.
   */
  override Expr getExpr() { result = this.getChild(0) }

  /** Gets the type of exception being thrown. */
  Class getThrownExceptionType() {
    result = getExpr().getType()
    or
    // Corner case: `throw null`
    this.getExpr().getType() instanceof NullType and
    result instanceof SystemNullReferenceExceptionClass
  }
}

/**
 * A `throw` expression, for example `throw new ArgumentException("i")` in
 * `return i != 0 ? 1 / i : throw new ArgumentException("i");`
 */
class ThrowExpr extends Expr, ThrowElement, @throw_expr {
  override string toString() { result = "throw ..." }

  /**
   * Gets the expression of the exception being thrown.
   *
   * For example, `new ArgumentException("i")` in
   * `return i != 0 ? 1 / i : throw new ArgumentException("i");`.
   */
  // overriden for more precise qldoc
  override Expr getExpr() { result = ThrowElement.super.getExpr() }
}

/**
 * An expression that may have a qualifier. Either a member access
 * (`MemberAccess`), an element access (`ElementAccess`), a method
 * call (`MethodCall`) or a property access (`PropertyAccess`), or
 * an accessor call (`AccessorCall`).
 */
class QualifiableExpr extends Expr, @qualifiable_expr {
  /**
   * Gets the declaration targeted by this expression, for example a method or
   * a field.
   */
  Declaration getQualifiedDeclaration() { none() }

  /** Gets the qualifier of this expression, if any. */
  Expr getQualifier() { result = this.getChildExpr(-1) }

  /** Holds if this expression is qualified. */
  final predicate hasQualifier() { exists(getQualifier()) }

  /** Holds if this expression has an implicit `this` qualifier. */
  predicate hasImplicitThisQualifier() { this.getQualifier().(ThisAccess).isImplicit() }

  /** Holds if this call has an implicit or explicit `this` qualifier. */
  predicate hasThisQualifier() {
    this.hasImplicitThisQualifier()
    or
    this.getQualifier().stripCasts() instanceof ThisAccess
  }

  /**
   * Holds if the target of this expression is a local instance. That is,
   * either the (implicit) qualifier is `this` or the qualifier is `base`.
   */
  predicate targetIsLocalInstance() {
    this.hasThisQualifier()
    or
    this.getQualifier() instanceof BaseAccess
  }

  /**
   * Holds if this expression is equivalent to a `this`-qualified version
   * of this expression
   */
  predicate targetIsThisInstance() {
    this.hasThisQualifier()
    or
    this.getQualifier() instanceof BaseAccess and
    not this.getQualifiedDeclaration().(Virtualizable).isOverridden()
  }

  /**
   * Holds if the target of this expression can be overridden or implemented.
   */
  predicate targetIsOverridableOrImplementable() {
    not this.getQualifier() instanceof BaseAccess and
    this.getQualifiedDeclaration().(Virtualizable).isOverridableOrImplementable()
  }

  /** Holds if this expression has a conditional qualifier `?.` */
  predicate isConditional() { conditional_access(this) }
}

private Expr getAnAssignOrForeachChild() {
  result = any(AssignExpr e).getLValue()
  or
  result = any(ForeachStmt fs).getVariableDeclTuple()
  or
  result = getAnAssignOrForeachChild().getAChildExpr()
}

/**
 * An expression representing a tuple, for example
 * `(1, 2)` on line 2 or `(var x, var y)` on line 5 in
 *
 * ```
 * class {
 *   (int, int) F() => (1, 2);
 *
 *   void M() {
 *     (var x, var y) = F();
 *   }
 * }
 * ```
 */
class TupleExpr extends Expr, @tuple_expr {
  override string toString() { result = "(..., ...)" }

  /** Gets the `i`th argument of this tuple. */
  Expr getArgument(int i) { result = getChild(i) }

  /** Gets an argument of this tuple. */
  Expr getAnArgument() { result = getArgument(_) }

  /** Holds if this tuple is a read access. */
  predicate isReadAccess() { not this = getAnAssignOrForeachChild() }
}

/**
 * A reference expression, for example `ref a[i]` on line 2 in
 *
 * ```
 * ref int GetElement(int[] a, int i) {
 *   return ref a[i];
 * }
 * ```
 */
class RefExpr extends Expr, @ref_expr {
  /** Gets the expression being referenced. */
  Expr getExpr() { result = getChild(0) }

  override string toString() { result = "ref ..." }

  override Type getType() { result = getExpr().getType() }
}

/**
 * A discard expression, for example `_` in
 *
 * ```
 * (var name, _, _) = GetDetails();
 * ```
 */
class DiscardExpr extends Expr, @discard_expr {
  override string toString() { result = "_" }
}
