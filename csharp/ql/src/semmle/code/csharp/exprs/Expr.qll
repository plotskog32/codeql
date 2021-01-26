/**
 * Provides all expression classes.
 *
 * All expressions have the common base class `Expr`.
 */

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
import semmle.code.csharp.Callable
import semmle.code.csharp.Location
import semmle.code.csharp.Stmt
import semmle.code.csharp.Type
private import dotnet
private import semmle.code.csharp.Enclosing::Internal
private import semmle.code.csharp.frameworks.System
private import semmle.code.csharp.TypeRef

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
  override Location getALocation() { expr_location(this, result) }

  /** Gets the type of this expression. */
  override Type getType() { expressions(this, _, getTypeRef(result)) }

  /** Gets the annotated type of this expression. */
  final AnnotatedType getAnnotatedType() { result.appliesTo(this) }

  /** Gets the value of this expression, if any */
  override string getValue() { expr_value(this, result) }

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

  /** Holds if the nullable flow state of this expression is not null. */
  predicate hasNotNullFlowState() { expr_flowstate(this, 1) }

  /** Holds if the nullable flow state of this expression may be null. */
  predicate hasMaybeNullFlowState() { expr_flowstate(this, 2) }
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
  /**
   * Gets the local variable being declared, if any. The only case where
   * no variable is declared is when a discard symbol is used, for example
   * ```csharp
   * if (int.TryParse(s, out var _))
   *     ...
   * ```
   */
  LocalVariable getVariable() { localvars(result, _, _, _, _, this) }

  /** Gets the name of the variable being declared, if any. */
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
    or
    not exists(this.getVariable()) and
    result = "_"
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

  override string getAPrimaryQlClass() {
    result = "LocalVariableDeclExpr" and
    not this instanceof LocalVariableDeclAndInitExpr
  }
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
 * ```csharp
 * 4 * (2 + 3)
 * ```
 */
class ParenthesizedExpr extends Expr, @par_expr {
  /** Gets the parenthesized expression. */
  Expr getExpr() { result = this.getChild(0) }

  override string toString() { result = "(...)" }

  override string getAPrimaryQlClass() { result = "ParenthesizedExpr" }
}

/**
 * A checked expression, for example `checked(2147483647 + ten)`.
 */
class CheckedExpr extends Expr, @checked_expr {
  /** Gets the checked expression. */
  Expr getExpr() { result = this.getChild(0) }

  override string toString() { result = "checked (...)" }

  override string getAPrimaryQlClass() { result = "CheckedExpr" }
}

/**
 * An unchecked expression, for example `unchecked(ConstantMax + 10)`.
 */
class UncheckedExpr extends Expr, @unchecked_expr {
  /** Gets the unchecked expression. */
  Expr getExpr() { result = this.getChild(0) }

  override string toString() { result = "unchecked (...)" }

  override string getAPrimaryQlClass() { result = "UncheckedExpr" }
}

cached
private predicate hasChildPattern(ControlFlowElement pm, Expr child) {
  child = pm.getChildExpr(1) and
  pm instanceof @is_expr
  or
  child = pm.getChildExpr(0) and
  pm instanceof @switch_case_expr
  or
  child = pm.getChildExpr(0) and
  pm instanceof @case_stmt
  or
  exists(Expr mid |
    hasChildPattern(pm, mid) and
    mid instanceof @recursive_pattern_expr
  |
    child = mid.getChild(2).getAChildExpr() or
    child = mid.getChild(3).getAChildExpr()
  )
  or
  exists(Expr mid |
    hasChildPattern(pm, mid) and
    mid instanceof @unary_pattern_expr and
    child = mid.getChild(0)
  )
  or
  exists(Expr mid | hasChildPattern(pm, mid) and mid instanceof @binary_pattern_expr |
    child = mid.getChild(0) or
    child = mid.getChild(1)
  )
}

/**
 * A pattern expression, for example `(_, false)` in
 *
 * ```csharp
 * (a,b) switch {
 *     (_, false) => true,
 *     _ => false
 * };
 * ```
 */
class PatternExpr extends Expr {
  private PatternMatch pm;

  PatternExpr() { hasChildPattern(pm, this) }

  /**
   * Gets the pattern match that this pattern expression belongs to
   * (transitively). For example, `_`, `false`, and `(_, false)` belong to the
   * pattern match `(_, false) => true` in
   *
   * ```csharp
   * (a,b) switch {
   *     (_, false) => true,
   *     _ => false
   * };
   * ```
   */
  PatternMatch getPatternMatch() { result = pm }
}

/** A discard pattern, for example `_` in `x is (_, false)` */
class DiscardPatternExpr extends DiscardExpr, PatternExpr {
  override string getAPrimaryQlClass() { result = "DiscardPatternExpr" }
}

/** A constant pattern, for example `false` in `x is (_, false)`. */
class ConstantPatternExpr extends PatternExpr {
  ConstantPatternExpr() { this.hasValue() }

  override string getAPrimaryQlClass() { result = "ConstantPatternExpr" }
}

/** A relational pattern, for example `>1` in `x is >1`. */
class RelationalPatternExpr extends PatternExpr, @relational_pattern_expr {
  /** Gets the name of the operator in this pattern. */
  string getOperator() { none() }

  /** Gets the expression of this relational pattern. */
  Expr getExpr() { result = this.getChild(0) }

  override string toString() { result = getOperator() + " ..." }
}

/** A less-than pattern, for example `< 10` in `x is < 10`. */
class LTPattern extends RelationalPatternExpr, @lt_pattern_expr {
  override string getOperator() { result = "<" }

  override string getAPrimaryQlClass() { result = "LTPattern" }
}

/** A greater-than pattern, for example `> 10` in `x is > 10`. */
class GTPattern extends RelationalPatternExpr, @gt_pattern_expr {
  override string getOperator() { result = ">" }

  override string getAPrimaryQlClass() { result = "GTPattern" }
}

/** A less-than or equals pattern, for example `<= 10` in `x is <= 10`. */
class LEPattern extends RelationalPatternExpr, @le_pattern_expr {
  override string getOperator() { result = "<=" }

  override string getAPrimaryQlClass() { result = "LEPattern" }
}

/** A greater-than or equals pattern, for example `>= 10` in `x is >= 10` */
class GEPattern extends RelationalPatternExpr, @ge_pattern_expr {
  override string getOperator() { result = ">=" }

  override string getAPrimaryQlClass() { result = "GEPattern" }
}

/**
 * A type pattern, for example `string` in `x is string`, `string s` in
 * `x is string s`, or `string _` in `x is string _`.
 */
class TypePatternExpr extends PatternExpr {
  private Type t;

  TypePatternExpr() {
    t = this.(TypeAccess).getTarget() or
    t = this.(LocalVariableDeclExpr).getVariable().getType()
  }

  /** Gets the type checked by this pattern. */
  Type getCheckedType() { result = t }
}

/** A type access pattern, for example `string` in `x is string`. */
class TypeAccessPatternExpr extends TypePatternExpr, TypeAccess {
  override string getAPrimaryQlClass() { result = "TypeAccessPatternExpr" }
}

/** A pattern that may bind a variable, for example `string s` in `x is string s`. */
class BindingPatternExpr extends PatternExpr {
  BindingPatternExpr() {
    this instanceof LocalVariableDeclExpr or
    this instanceof @recursive_pattern_expr
  }

  /**
   * Gets the local variable declaration of this pattern, if any. For example,
   * `string s` in `string { Length: 5 } s`.
   */
  LocalVariableDeclExpr getVariableDeclExpr() { none() }
}

/** A variable declaration pattern, for example `string s` in `x is string s`. */
class VariablePatternExpr extends BindingPatternExpr, LocalVariableDeclExpr {
  override LocalVariableDeclExpr getVariableDeclExpr() { result = this }

  override string getAPrimaryQlClass() { result = "VariablePatternExpr" }
}

/**
 * A recursive pattern expression, for example `string { Length: 5 } s` in
 * `x is string { Length: 5 } s`.
 */
class RecursivePatternExpr extends BindingPatternExpr, @recursive_pattern_expr {
  override string toString() { result = "{ ... }" }

  override string getAPrimaryQlClass() { result = "RecursivePatternExpr" }

  /**
   * Gets the position patterns of this recursive pattern, if any.
   * For example, `(1, _)`.
   */
  PositionalPatternExpr getPositionalPatterns() { result = this.getChild(2) }

  /**
   * Gets the property patterns of this recursive pattern, if any.
   * For example, `{ Length: 5 }` in `o is string { Length: 5 } s`
   */
  PropertyPatternExpr getPropertyPatterns() { result = this.getChild(3) }

  /**
   * Gets the type access of this recursive pattern, if any.
   * For example, `string` in `string { Length: 5 }`
   */
  TypeAccess getTypeAccess() { result = this.getChild(1) }

  override LocalVariableDeclExpr getVariableDeclExpr() { result = this.getChild(0) }
}

/** A property pattern. For example, `{ Length: 5 }`. */
class PropertyPatternExpr extends Expr, @property_pattern_expr {
  override string toString() { result = "{ ... }" }

  /** Gets the `n`th pattern. */
  PatternExpr getPattern(int n) { result = this.getChild(n) }

  override string getAPrimaryQlClass() { result = "PropertyPatternExpr" }
}

/**
 * A labeled pattern in a property pattern, for example `Length: 5` in
 * `{ Length: 5 }`.
 */
class LabeledPatternExpr extends PatternExpr {
  LabeledPatternExpr() { this.getParent() instanceof PropertyPatternExpr }

  /** Gets the label of this pattern. */
  string getLabel() { exprorstmt_name(this, result) }

  override string getAPrimaryQlClass() { result = "LabeledPatternExpr" }
}

/** A positional pattern. For example, `(int x, int y)`. */
class PositionalPatternExpr extends Expr, @positional_pattern_expr {
  override string toString() { result = "( ... )" }

  /** Gets the `n`th pattern. */
  PatternExpr getPattern(int n) { result = this.getChild(n) }

  override string getAPrimaryQlClass() { result = "PositionalPatternExpr" }
}

/** A unary pattern. For example, `not 1`. */
class UnaryPatternExpr extends PatternExpr, @unary_pattern_expr {
  /** Gets the underlying pattern. */
  PatternExpr getPattern() { result = this.getChild(0) }
}

/** A not pattern. For example, `not 1`. */
class NotPatternExpr extends UnaryPatternExpr, @not_pattern_expr {
  override string toString() { result = "not ..." }

  override string getAPrimaryQlClass() { result = "NotPatternExpr" }
}

/** A binary pattern. For example, `1 or 2`. */
class BinaryPatternExpr extends PatternExpr, @binary_pattern_expr {
  /** Gets a pattern. */
  PatternExpr getAnOperand() { result = getLeftOperand() or result = getRightOperand() }

  /** Gets the left pattern. */
  PatternExpr getLeftOperand() { result = this.getChild(0) }

  /** Gets the right pattern. */
  PatternExpr getRightOperand() { result = this.getChild(1) }
}

/** A binary or pattern. For example, `1 or 2`. */
class OrPatternExpr extends BinaryPatternExpr, @or_pattern_expr {
  override string toString() { result = "... or ..." }

  override string getAPrimaryQlClass() { result = "OrPatternExpr" }
}

/** A binary and pattern. For example, `< 1 and > 2`. */
class AndPatternExpr extends BinaryPatternExpr, @and_pattern_expr {
  override string toString() { result = "... and ..." }

  override string getAPrimaryQlClass() { result = "AndPatternExpr" }
}

/**
 * An expression or statement that matches the value of an expression against
 * a pattern. Either an `is` expression or a `case` expression/statement.
 */
class PatternMatch extends ControlFlowElement, @pattern_match {
  /** Gets the pattern of this match. */
  PatternExpr getPattern() { none() }

  /** Gets the expression that is matched against a pattern. */
  Expr getExpr() { none() }
}

/** An `is` expression. */
class IsExpr extends Expr, PatternMatch, @is_expr {
  /** Gets the expression being checked, for example `x` in `x is string`. */
  override Expr getExpr() { result = this.getChild(0) }

  override PatternExpr getPattern() { result = this.getChild(1) }

  override string toString() { result = "... is ..." }

  override string getAPrimaryQlClass() { result = "IsExpr" }
}

/** A `switch` expression or statement. */
class Switch extends ControlFlowElement, @switch {
  /** Gets the `i`th case of this `switch`. */
  Case getCase(int i) { none() }

  /** Gets a case of this `switch`. */
  Case getACase() { result = this.getCase(_) }

  /**
   * Gets the expression being switched against. For example, `x` in
   * `x switch { ... }`.
   */
  Expr getExpr() { none() }
}

/**
 * A `switch` expression, for example
 * ```csharp
 * (a,b) switch {
 *     (false, false) => true,
 *     _ => false
 * };
 * ```
 */
class SwitchExpr extends Expr, Switch, @switch_expr {
  override string toString() { result = "... switch { ... }" }

  override Expr getExpr() { result = this.getChild(-1) }

  override SwitchCaseExpr getCase(int n) { result = this.getChild(n) }

  override SwitchCaseExpr getACase() { result = this.getCase(_) }

  override string getAPrimaryQlClass() { result = "SwitchExpr" }
}

/** A `case` expression or statement. */
class Case extends PatternMatch, @case {
  /**
   * Gets the `when` expression of this case, if any. For example, `s.Length < 10`
   * in `string s when s.Length < 10 => s`
   */
  Expr getCondition() { none() }

  /** Gets the body of this `case`. */
  ControlFlowElement getBody() { none() }
}

/** An arm of a switch expression, for example `(false, false) => true`. */
class SwitchCaseExpr extends Expr, Case, @switch_case_expr {
  override string toString() { result = "... => ..." }

  override Expr getExpr() { result = any(SwitchExpr se | se.getCase(_) = this).getExpr() }

  override PatternExpr getPattern() { result = this.getChild(0) }

  override Expr getCondition() { result = this.getChild(1) }

  /**
   * Gets the result of a switch arm, for example `true` in
   * `(false, false) => true`.
   */
  override Expr getBody() { result = this.getChild(2) }

  /** Holds if this case expression matches all expressions. */
  predicate matchesAll() {
    // Note: There may be other cases that are not yet handled by this predicate.
    // For example, `(1,2) switch { (int x, int y) => x+y }`
    // should match all cases due to the type of the expression.
    this.getPattern() instanceof DiscardPatternExpr
  }

  override string getAPrimaryQlClass() { result = "SwitchCaseExpr" }
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
  Type getTargetType() { result = this.getType() }

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
 * ```csharp
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
 * ```csharp
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

  override string getAPrimaryQlClass() { result = "AsExpr" }
}

/**
 * A cast expression, for example `(string) x`.
 */
class CastExpr extends Cast, @cast_expr {
  override string toString() { result = "(...) ..." }

  override string getAPrimaryQlClass() { result = "CastExpr" }
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

  override string getAPrimaryQlClass() { result = "TypeofExpr" }
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

  override string getAPrimaryQlClass() { result = "DefaultValueExpr" }
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

  override string getAPrimaryQlClass() { result = "SizeofExpr" }
}

/**
 * A pointer indirection operation, for example `*pn` on line 7,
 * `pa->M()` on line 13, and `cp[1]` on line 18 in
 *
 * ```csharp
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

  override string getAPrimaryQlClass() { result = "PointerIndirectionExpr" }
}

/**
 * An address-of expression, for example `&n` on line 4 in
 *
 * ```csharp
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

  override string getAPrimaryQlClass() { result = "AddressOfExpr" }
}

/**
 * An `await` expression, for example `await AsyncMethodThatReturnsTask()`.
 */
class AwaitExpr extends Expr, @await_expr {
  /** Gets the expression being awaited. */
  Expr getExpr() { result = getChild(0) }

  override string toString() { result = "await ..." }

  override string getAPrimaryQlClass() { result = "AwaitExpr" }
}

/**
 * A `nameof` expression, for example `nameof(s)` on line 3 in
 *
 * ```csharp
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

  override string getAPrimaryQlClass() { result = "NameOfExpr" }
}

/**
 * An interpolated string, for example `$"Hello, {name}!"` on line 2 in
 *
 * ```csharp
 * void Hello(string name) {
 *   Console.WriteLine($"Hello, {name}!");
 * }
 * ```
 */
class InterpolatedStringExpr extends Expr, @interpolated_string_expr {
  override string toString() { result = "$\"...\"" }

  override string getAPrimaryQlClass() { result = "InterpolatedStringExpr" }

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

  override string getAPrimaryQlClass() { result = "ThrowExpr" }
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
 * ```csharp
 * class C {
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

  override string getAPrimaryQlClass() { result = "TupleExpr" }
}

/**
 * A reference expression, for example `ref a[i]` on line 2 in
 *
 * ```csharp
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

  override string getAPrimaryQlClass() { result = "RefExpr" }
}

/**
 * A discard expression, for example `_` in
 *
 * ```csharp
 * (var name, _, _) = GetDetails();
 * ```
 */
class DiscardExpr extends Expr, @discard_expr {
  override string toString() { result = "_" }

  override string getAPrimaryQlClass() { result = "DiscardExpr" }
}

private class UnknownExpr extends Expr, @unknown_expr {
  override string toString() { result = "Expression" }
}

/**
 * A range expression, used to create a `System.Range`. For example
 * ```csharp
 * 1..3
 * 1..^1
 * 3..
 * ..
 * ..5
 * ..^1
 * ```
 */
class RangeExpr extends Expr, @range_expr {
  override string toString() { result = "... .. ..." }

  /** Gets the left hand operand of this range expression, if any. */
  Expr getStart() { result = this.getChild(0) }

  /** Gets the right hand operand of this range expression, if any. */
  Expr getEnd() { result = this.getChild(1) }

  /** Holds if this range expression has a left hand operand. */
  predicate hasStart() { exists(this.getStart()) }

  /** Holds if this range expression has a right hand operand. */
  predicate hasEnd() { exists(this.getEnd()) }

  override string getAPrimaryQlClass() { result = "RangeExpr" }
}

/** An index expression, for example `^1` meaning "1 from the end". */
class IndexExpr extends Expr, @index_expr {
  /** Gets the sub expression of this index expression. */
  Expr getExpr() { result.getParent() = this }

  override string toString() { result = "^..." }

  override string getAPrimaryQlClass() { result = "IndexExpr" }
}

/**
 * A nullable warning suppression expression, for example `x!` in
 * ```csharp
 * string GetName()
 * {
 *     string? x = ...;
 *     return x!;
 * }
 * ```
 */
class SuppressNullableWarningExpr extends Expr, @suppress_nullable_warning_expr {
  /** Gets the expression, for example `x` in `x!`. */
  Expr getExpr() { result.getParent() = this }

  override string toString() { result = "...!" }

  override string getAPrimaryQlClass() { result = "SuppressNullableWarningExpr" }
}
