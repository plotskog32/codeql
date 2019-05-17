
import semmle.code.cpp.Element
private import semmle.code.cpp.Enclosing
private import semmle.code.cpp.internal.ResolveClass
private import semmle.code.cpp.internal.AddressConstantExpression

/**
 * A C/C++ expression.
 */
class Expr extends StmtParent, @expr {
  /** Gets the nth child of this expression. */
  Expr getChild(int n) { exprparents(unresolveElement(result),n,underlyingElement(this)) }

  /** Gets the number of direct children of this expression. */
  int getNumChild() { result = count(this.getAChild()) }

  /** Holds if e is the nth child of this expression. */
  predicate hasChild(Expr e, int n) { e = this.getChild(n) }

  /** Gets the enclosing function of this expression, if any. */
  Function getEnclosingFunction() { result = exprEnclosingElement(this) }

  /** Gets the nearest enclosing set of curly braces around this expression in the source, if any. */
  Block getEnclosingBlock() {
      result = getEnclosingStmt().getEnclosingBlock()
  }

  override Stmt getEnclosingStmt() {
      result = this.getParent().(Expr).getEnclosingStmt() or
      result = this.getParent().(Stmt) or
      exists(Expr other | result = other.getEnclosingStmt() and other.getConversion() = this) or
      exists(DeclStmt d, LocalVariable v | d.getADeclaration() = v and v.getInitializer().getExpr() = this and result = d) or
      exists(ConditionDeclExpr cde, LocalVariable v | cde.getVariable() = v and v.getInitializer().getExpr() = this and result = cde.getEnclosingStmt())
  }

  /** Gets the enclosing variable of this expression, if any. */
  Variable getEnclosingVariable() { result = exprEnclosingElement(this) }

  /** Gets a child of this expression. */
  Expr getAChild() { exists (int n | result = this.getChild(n)) }

  /** Gets the parent of this expression, if any. */
  Element getParent() { exprparents(underlyingElement(this),_,unresolveElement(result)) }

  /** Gets the location of this expression. */
  override Location getLocation() { exprs(underlyingElement(this),_,result) }

  /** Holds if this is an auxiliary expression generated by the compiler. */
  predicate isCompilerGenerated() {
    compgenerated(underlyingElement(this)) or
    this.getParent().(ConstructorFieldInit).isCompilerGenerated()
  }

  /**
   * Gets the type of this expression.
   *
   * As the type of an expression can sometimes be a TypedefType, calling getUnderlyingType()
   * is often more useful than calling this predicate.
   */
  pragma[nomagic] cached Type getType() { expr_types(underlyingElement(this),unresolveElement(result),_) }

  /**
   * Gets the type of this expression after typedefs have been resolved.
   *
   * In most cases, this predicate will be the same as getType().  It will
   * only differ when the result of getType() is a TypedefType, in which
   * case this predicate will (possibly recursively) resolve the typedef.
   */
  Type getUnderlyingType() { result = this.getType().getUnderlyingType() }

  /**
   * Gets an integer indicating the type of expression that this represents.
   * 
   * Consider using subclasses of `Expr` rather than relying on this predicate. 
   */
  int getKind() { exprs(underlyingElement(this),result,_) }

  /** Gets a textual representation of this expression. */
  override string toString() { none() }

  /** Gets the value of this expression, if it is a constant. */
  string getValue() { exists(@value v | values(v,result,_) and valuebind(v,underlyingElement(this))) }

  /** Gets the source text for the value of this expression, if it is a constant. */
  string getValueText() { exists(@value v | values(v,_,result) and valuebind(v,underlyingElement(this))) }
  
  /** Holds if this expression has a value that can be determined at compile time. */
  cached
  predicate isConstant() {
    valuebind(_,underlyingElement(this))
    or
    addressConstantExpression(this)
  }

  /**
   * Holds if this expression is side-effect free (conservative
   * approximation). This predicate cannot be overridden;
   * override mayBeImpure() instead.
   *
   * Note that this predicate does not strictly correspond with
   * the usual definition of a 'pure' function because reading
   * from global state is permitted, just not writing / output.
   */
  final predicate isPure() {
    not this.mayBeImpure()
  }

  /**
   * Holds if it is possible that the expression may be impure. If we are not
   * sure, then it holds.
   */
  predicate mayBeImpure() {
    any()
  }

  /**
   * Holds if it is possible that the expression may be impure. If we are not
   * sure, then it holds. Unlike `mayBeImpure()`, this predicate does not
   * consider modifications to temporary local variables to be impure. If you
   * call a function in which nothing may be globally impure then the function
   * as a whole will have no side-effects, even if it mutates its own fresh
   * stack variables.
   */
  predicate mayBeGloballyImpure() {
    any()
  }

  /**
   * Holds if this expression is an lvalue. An lvalue is an expression that
   * represents a location, rather than a value.
   * See [basic.lval] for more about lvalues.
   */
  predicate isLValueCategory() {
    expr_types(underlyingElement(this), _, 3)
  }

  /**
   * Holds if this expression is an xvalue. An xvalue is a location whose
   * lifetime is about to end (e.g. an rvalue reference returned from a function
   * call).
   * See [basic.lval] for more about xvalues.
   */
  predicate isXValueCategory() {
    expr_types(underlyingElement(this), _, 2)
  }

  /**
   * Holds if this expression is a prvalue. A prvalue is an expression that
   * represents a value, rather than a location.
   * See [basic.lval] for more about prvalues.
   */
  predicate isPRValueCategory() {
    expr_types(underlyingElement(this), _, 1)
  }

  /**
   * Holds if this expression is a glvalue. A glvalue is either an lvalue or an
   * xvalue.
   */
  predicate isGLValueCategory() {
    isLValueCategory() or isXValueCategory()
  }

  /**
   * Holds if this expression is an rvalue. An rvalue is either a prvalue or an
   * xvalue.
   */
  predicate isRValueCategory() {
    isPRValueCategory() or isXValueCategory()
  }
  
  /**
   * Gets a string representation of the value category of the expression.
   * This is intended only for debugging. The possible values are:
   *
   * - "lvalue"
   * - "xvalue"
   * - "prvalue"
   * - "prvalue(load)"
   *
   * The "prvalue(load)" string is used when the expression is a prvalue, but
   * `hasLValueToRvalueConversion()` holds.
   */
  string getValueCategoryString() {
  	(
      isLValueCategory() and
      result = "lvalue"
    ) or (
      isXValueCategory() and
      result = "xvalue"
    ) or (
      isPRValueCategory() and
      if hasLValueToRValueConversion() then
        result = "prvalue(load)"
      else
        result = "prvalue"
        
    )
  }

  /**
   * Gets the parent of this expression, if any, in an alternative syntax tree
   * that has `Conversion`s as part of the tree.
   */
  Element getParentWithConversions() { convparents(this,_,result) }
  
  /**
   * Holds if this expression will not be evaluated because of its context,
   * such as an expression inside a sizeof.
   */
  predicate isUnevaluated() {
    exists (Element e |
      e = getParentWithConversions+() |
      e instanceof SizeofOperator or
      exists ( Expr e2 |
        e.(TypeidOperator).getExpr() = e2 and
        (
          not e2.getActualType().getUnspecifiedType().(Class).isPolymorphic() or
          not e2.isGLValueCategory()
        )
      ) or
      e instanceof NoExceptExpr or
      e instanceof AlignofOperator
    ) or exists (Decltype d |
      d.getExpr() = getParentWithConversions*()
    )
  }
  
  /**
   * Holds if this expression has undergone an lvalue-to-rvalue conversion to
   * extract its value.
   * for example:
   * ```
   *  y = x;
   * ```
   * The VariableAccess for `x` is a prvalue, and hasLValueToRValueConversion()
   * holds because the value of `x` was loaded from the location of `x`.
   * The VariableAccess for `y` is an lvalue, and hasLValueToRValueConversion()
   * does not hold because the value of `y` was not extracted.
   *
   * See [conv.lval] for more about the lvalue-to-rvalue conversion
   */
  predicate hasLValueToRValueConversion() {
    expr_isload(underlyingElement(this))
  }

  /**
   * Holds if this expression is an LValue, in the sense of having an address.
   *
   * Being an LValue is best approximated as having an address.
   * This is a strict superset of modifiable LValues, which are best approximated by things which could be on the left-hand side of an assignment.
   * This is also a strict superset of expressions which provide an LValue, which is best approximated by things whose address is important.
   *
   * See [basic.lval] in the C++ language specification.
   * In C++03, every expression is either an LValue or an RValue.
   * In C++11, every expression is exactly one of an LValue, an XValue, or a PRValue (with RValues being the union of XValues and PRValues).
   * Using the C++11 terminology, this predicate selects expressions whose value category is lvalue.
   */
  predicate isLValue() {
    this instanceof StringLiteral /* C++ n3337 - 5.1.1 clause 1 */
    or this.(ParenthesisExpr).getExpr().isLValue() /* C++ n3337 - 5.1.1 clause 6 */
    or (this instanceof VariableAccess and not this instanceof FieldAccess) /* C++ n3337 - 5.1.1 clauses 8 and 9, variables and data members */
    or exists(FunctionAccess fa | fa = this | /* C++ n3337 - 5.1.1 clauses 8 and 9, functions */
      fa.getTarget().isStatic()
      or not fa.getTarget().isMember()
    )
    or this instanceof ArrayExpr /* C++ n3337 - 5.2.1 clause 1 */
    or this.getType() instanceof ReferenceType /* C++ n3337 - 5.2.2 clause 10
                                                              5.2.5 clause 4, no bullet point
                                                              5.2.7 clauses 2 and 5
                                                              5.2.9 clause 1
                                                              5.2.10 clause 1
                                                              5.2.11 clause 1
                                                              5.4 clause 1 */
    or this.(FieldAccess).getQualifier().isLValue() /* C++ n3337 - 5.2.5 clause 4, 2nd bullet point */
    or this instanceof TypeidOperator /* C++ n3337 - 5.2.8 clause 1 */
    or this instanceof PointerDereferenceExpr /* C++ n3337 - 5.3.1 clause 1 */
    or this instanceof PrefixIncrExpr /* C++ n3337 - 5.3.2 clause 1 */
    or this instanceof PrefixDecrExpr /* C++ n3337 - 5.3.2 clause 2 */
    or exists(ConditionalExpr ce | ce = this | /* C++ n3337 - 5.16 clause 4 */
      ce.getThen().isLValue() and
      ce.getElse().isLValue() and
      ce.getThen().getType() = ce.getElse().getType()
    )
    or this instanceof Assignment /* C++ n3337 - 5.17 clause 1 */
    or this.(CommaExpr).getRightOperand().isLValue() /* C++ n3337 - 5.18 clause 1 */
  }

  /**
   * Gets the precedence of the main operator of this expression;
   * higher precedence binds tighter.
   */
  int getPrecedence() {
    none()
  }

  /**
   * Holds if this expression has a conversion.
   *
   * Type casts and parameterized expressions are not part of the main
   * expression tree structure but attached on the nodes they convert,
   * for example:
   * ```
   *  2 + (int)(bool)1
   * ```
   * has the main tree:
   * ```
   *  2 + 1
   * ```
   * and 1 has a bool conversion, while the bool conversion itself has
   * an int conversion.
   */
  predicate hasConversion() { exists(Expr e | exprconv(underlyingElement(this),unresolveElement(e))) }

  /**
   * Holds if this expression has an implicit conversion.
   * 
   * For example in `char *str = 0`, the `0` has an implicit conversion to type `char *`.
   */
  predicate hasImplicitConversion() { exists(Expr e | exprconv(underlyingElement(this),unresolveElement(e)) and e.(Cast).isImplicit()) }

  /**
   * Holds if this expression has an explicit conversion.
   * 
   * For example in `(MyClass *)ptr`, the `ptr` has an explicit
   * conversion to type `MyClass *`.
   */
  predicate hasExplicitConversion() { exists(Expr e | exprconv(underlyingElement(this),unresolveElement(e)) and not e.(Cast).isImplicit()) }

  /**
   * Gets the conversion associated with this expression, if any.
   */
  Expr getConversion() { exprconv(underlyingElement(this),unresolveElement(result)) }

  /**
   * Gets a string describing the conversion associated with this expression,
   * or "" if there is none.
   */
  string getConversionString() { (result = this.getConversion().toString() and this.hasConversion()) or (result = "" and not this.hasConversion()) }

  /** Gets the fully converted form of this expression, including all type casts and other conversions. */
  cached
  Expr getFullyConverted() {
    hasNoConversions(this) and
    result = this
    or
    result = this.getConversion().getFullyConverted()
  }

  /**
   * Gets this expression with all of its explicit casts, but none of its
   * implicit casts. More precisely this takes conversions up to the last
   * explicit cast (there may be implicit conversions along the way), but does
   * not include conversions after the last explicit cast.
   *
   * C++ example: `C c = (B)d` might have three casts: (1) an implicit cast
   * from A to some D, (2) an explicit cast from D to B, and (3) an implicit
   * cast from B to C. Only (1) and (2) would be included.
   */
  Expr getExplicitlyConverted() {
    // result is this or one of its conversions
    result = this.getConversion*() and
    // result is not an implicit conversion - it's either the expr or an explicit cast
    (result = this or not result.(Cast).isImplicit()) and
    // there is no further explicit conversion after result
    not exists(Cast other | other = result.getConversion+() and not other.isImplicit())
  }

  /**
   * Gets this expression with all of its initial implicit casts, but none of
   * its explicit casts. More precisely, this takes all implicit conversions
   * up to (but not including) the first explicit cast (if any).
   */
  Expr getImplicitlyConverted() {
    if this.hasImplicitConversion() then
      result = this.getConversion().getImplicitlyConverted()
    else
      result = this
  }
 
  /**
   * Gets the type of this expression, after any implicit conversions and explicit casts, and after resolving typedefs.
   *
   * As an example, consider the AST fragment `(i64)(void*)0` in the context of `typedef long long i64;`. The fragment
   * contains three expressions: two CStyleCasts and one literal Zero. For all three expressions, the result of this
   * predicate will be `long long`.
   */
  Type getActualType() {
    result = this.getFullyConverted().getType().getUnderlyingType()
  }

  /** Holds if this expression is parenthesised. */
  predicate isParenthesised() { this.getConversion() instanceof ParenthesisExpr }

  /** Gets the function containing this control-flow node. */
  override Function getControlFlowScope() {
    result = this.getEnclosingFunction()
  }
}

/**
 * A C/C++ operation.
 */
abstract class Operation extends Expr {
  /** Gets the operator of this operation. */
  abstract string getOperator();

  /** Gets an operand of this operation. */
  Expr getAnOperand() {
    result = this.getAChild()
  }
}

/**
 * A C/C++ unary operation.
 */
abstract class UnaryOperation extends Operation {
  /** Gets the operand of this unary operation. */
  Expr getOperand() { this.hasChild(result,0) }

  override string toString() { result = this.getOperator() + " ..." }

  override predicate mayBeImpure() {
    this.getOperand().mayBeImpure()
  }
  override predicate mayBeGloballyImpure() {
    this.getOperand().mayBeGloballyImpure()
  }
}

/**
 * A C/C++ binary operation.
 */
abstract class BinaryOperation extends Operation {
  /** Gets the left operand of this binary operation. */
  Expr getLeftOperand() { this.hasChild(result,0) }

  /** Gets the right operand of this binary operation. */
  Expr getRightOperand() { this.hasChild(result,1) }

  override string toString() { result = "... " + this.getOperator() + " ..." }

  override predicate mayBeImpure() {
    this.getLeftOperand().mayBeImpure() or
    this.getRightOperand().mayBeImpure()
  }
  override predicate mayBeGloballyImpure() {
    this.getLeftOperand().mayBeGloballyImpure() or
    this.getRightOperand().mayBeGloballyImpure()
  }
}

/**
 * A C++11 parenthesized braced initializer list within a template.
 *
 * This is used to represent particular syntax within templates where the final
 * form of the expression is not known. In actual instantiations, it will have
 * been turned into a constructor call or aggregate initializer or similar.
 */
class ParenthesizedBracedInitializerList extends Expr, @braced_init_list {
  override string toString() { result = "({...})" }
}

/**
 * A C/C++ parenthesis expression.
*/
class ParenthesisExpr extends Conversion, @parexpr {
  override string toString() { result = "(...)" }
}

/**
 * A C/C++ expression that has not been resolved.
 */
class ErrorExpr extends Expr, @errorexpr {
  override string toString() { result = "<error expr>" }
}

/**
 * A Microsoft C/C++ __assume expression.
 */
class AssumeExpr extends Expr, @assume {
  override string toString() { result = "__assume(...)" }
}

/**
 * A C/C++ comma expression.
 */
class CommaExpr extends Expr, @commaexpr {
  /**
   * Gets the left operand, which is the one whose value is discarded.
   */
  Expr getLeftOperand() { this.hasChild(result,0) }

  /**
   * Gets the right operand, which is the one whose value is equal to the value
   * of the comma expression itself.
   */
  Expr getRightOperand() { this.hasChild(result,1) }

  override string toString() { result = "... , ..." }

  override int getPrecedence() { result = 0 }

  override predicate mayBeImpure() {
    this.getLeftOperand().mayBeImpure() or
    this.getRightOperand().mayBeImpure()
  }
  override predicate mayBeGloballyImpure() {
    this.getLeftOperand().mayBeGloballyImpure() or
    this.getRightOperand().mayBeGloballyImpure()
  }
}

/**
 * A C/C++ address-of expression.
 */
class AddressOfExpr extends UnaryOperation, @address_of {
  /** Gets the function or variable whose address is taken. */
  Declaration getAddressable() {
       result = this.getOperand().(Access).getTarget()
       // this handles the case where we are taking the address of a reference variable
    or result = this.getOperand().(ReferenceDereferenceExpr).getChild(0).(Access).getTarget()
  }

  override string getOperator() { result = "&" }

  override int getPrecedence() { result = 15 }

  override predicate mayBeImpure() {
    this.getOperand().mayBeImpure()
  }
  override predicate mayBeGloballyImpure() {
    this.getOperand().mayBeGloballyImpure()
  }
}

/**
 * An implicit conversion from type T to type T&amp;.
 *
 * This typically occurs when an expression of type T is used to initialize a variable or parameter of
 * type T&amp;, and is to reference types what AddressOfExpr is to pointer types - though this class is
 * considered to be a conversion rather than an operation, and as such doesn't occur in the main AST.
 */
class ReferenceToExpr extends Conversion, @reference_to {
  override string toString() { result = "(reference to)" }

  override int getPrecedence() { result = 15 }
}

/**
 * An instance of unary operator * applied to a built-in type.
 *
 * For user-defined types, see OverloadedPointerDereferenceExpr.
 */
class PointerDereferenceExpr extends UnaryOperation, @indirect {
  /**
   * DEPRECATED: Use getOperand() instead.
   *
   * Gets the expression that is being dereferenced.
   */
  deprecated Expr getExpr() {
    result = getOperand()
  }

  override string getOperator() { result = "*" }

  override int getPrecedence() { result = 15 }

  override predicate mayBeImpure() {
    this.getChild(0).mayBeImpure() or
    this.getChild(0).getFullyConverted().getType().(DerivedType).getBaseType().isVolatile()
  }
  override predicate mayBeGloballyImpure() {
    this.getChild(0).mayBeGloballyImpure() or
    this.getChild(0).getFullyConverted().getType().(DerivedType).getBaseType().isVolatile()
  }
}

/**
 * An implicit conversion from type T&amp; to type T.
 *
 * This typically occurs when an variable of type T&amp; is used in a context which expects type T, and
 * is to reference types what PointerDereferenceExpr is to pointer types - though this class is
 * considered to be a conversion rather than an operation, and as such doesn't occur in the main AST.
 */
class ReferenceDereferenceExpr extends Conversion, @ref_indirect {
  override string toString() { result = "(reference dereference)" }
}

/**
 * A C++ `new` or `new[]` expression.
 */
class NewOrNewArrayExpr extends Expr, @any_new_expr {
  override int getPrecedence() { result = 15 }

  /**
   * Gets the `operator new` or `operator new[]` that allocates storage.
   */
  Function getAllocator() {
    expr_allocator(underlyingElement(this), unresolveElement(result), _)
  }

  /**
   * Holds if the allocation function is the version that expects an alignment
   * argument of type `std::align_val_t`.
   */
  predicate hasAlignedAllocation() {
    expr_allocator(underlyingElement(this), _, 1)
  }

  /**
   * Gets the alignment argument passed to the allocation function, if any.
   */
  Expr getAlignmentArgument() {
    hasAlignedAllocation() and
    (
      // If we have an allocator call, the alignment is the second argument to
      // that call.
      result = getAllocatorCall().getArgument(1) or
      // Otherwise, the alignment winds up as child number 3 of the `new`
      // itself.
      result = getChild(3)
    )
  }

  /**
   * Gets the call to a non-default `operator new` that allocates storage, if any.
   *
   * As a rule of thumb, there will be an allocator call precisely when the type
   * being allocated has a custom `operator new`, or when an argument list appears
   * after the `new` keyword and before the name of the type being allocated.
   *
   * In particular note that uses of placement-new and nothrow-new will have an
   * allocator call.
   */
  FunctionCall getAllocatorCall() { result = this.getChild(0) }

  /**
   * Gets the `operator delete` that deallocates storage if the initialization
   * throws an exception, if any.
   */
  Function getDeallocator() {
    expr_deallocator(underlyingElement(this), unresolveElement(result), _)
  }

  /**
   * Holds if the deallocation function expects a size argument.
   */
  predicate hasSizedDeallocation() {
    exists(int form |
      expr_deallocator(underlyingElement(this), _, form) and
      form.bitAnd(1) != 0  // Bit zero is the "size" bit
    )
  }

  /**
   * Holds if the deallocation function expects an alignment argument.
   */
  predicate hasAlignedDeallocation() {
    exists(int form |
      expr_deallocator(underlyingElement(this), _, form) and
      form.bitAnd(2) != 0  // Bit one is the "alignment" bit
    )
  }

  /**
   * Gets the type that is being allocated.
   *
   * For example, for `new int` the result is `int`.
   * For `new int[5]` the result is `int[5]`.
   */
  abstract Type getAllocatedType();

  /**
   * Gets the pointer `p` if this expression is of the form `new(p) T...`.
   * Invocations of this form are non-allocating `new` expressions that may
   * call the constructor of `T` but will not allocate memory.
   */
  Expr getPlacementPointer() {
    isStandardPlacementNewAllocator(this.getAllocator()) and
    result = this.getAllocatorCall().getArgument(1)
  }
}

/**
 * A C++ `new` (non-array) expression.
 */
class NewExpr extends NewOrNewArrayExpr, @new_expr {
  override string toString() { result = "new" }

  /**
   * Gets the type that is being allocated.
   *
   * For example, for `new int` the result is `int`.
   */
  override Type getAllocatedType() {
    new_allocated_type(underlyingElement(this), unresolveElement(result))
  }

  /**
   * Gets the call or expression that initializes the allocated object, if any.
   *
   * As examples, for `new int(4)`, this will be `4`, and for `new std::vector(4)`, this will
   * be a call to the constructor `std::vector::vector(size_t)` with `4` as an argument.
   */
  Expr getInitializer() { result = this.getChild(1) }
}

/**
 * A C++ `new[]` (array) expression.
 */
class NewArrayExpr extends NewOrNewArrayExpr, @new_array_expr {
  override string toString() { result = "new[]" }

  /**
   * Gets the type that is being allocated.
   *
   * For example, for `new int[5]` the result is `int[5]`.
   */
  override Type getAllocatedType() {
    new_array_allocated_type(underlyingElement(this), unresolveElement(result))
  }

  /**
   * Gets the element type of the array being allocated.
   */
  Type getAllocatedElementType() {
    result = getType().getUnderlyingType().(PointerType).getBaseType()
  }

  /**
   * Gets the call or expression that initializes the first element of the array, if any.
   *
   * This will either be a call to the default constructor for the array's element type (as
   * in `new std::string[10]`), or a literal zero for arrays of scalars which are zero-initialized
   * due to extra parentheses (as in `new int[10]()`).
   *
   * At runtime, the constructor will be called once for each element in the array, but the
   * constructor call only exists once in the AST.
   */
  Expr getInitializer() { result = this.getChild(1) }

  /**
   * Gets the extent of the non-constant array dimension, if any.
   *
   * As examples, for `new char[n]` and `new char[n][10]`, this gives `n`, but for `new char[10]` this
   * gives nothing, as the 10 is considered part of the type.
   */
  Expr getExtent() { result = this.getChild(2) }
}

/**
 * A C++ `delete` (non-array) expression.
 */
class DeleteExpr extends Expr, @delete_expr {
  override string toString() { result = "delete" }

  override int getPrecedence() { result = 15 }

  /**
   * Gets the compile-time type of the object being deleted.
   */
  Type getDeletedObjectType() {
    result = getExpr().getFullyConverted().getType().stripTopLevelSpecifiers().(PointerType).getBaseType()
  }

  /**
   * Gets the call to a destructor that occurs prior to the object's memory being deallocated, if any.
   */
  DestructorCall getDestructorCall() { result = this.getChild(1) }

  /**
   * Gets the destructor to be called to destroy the object, if any.
   */
  Destructor getDestructor() { result = getDestructorCall().getTarget() }

  /**
   * Gets the `operator delete` that deallocates storage. Does not hold
   * if the type being destroyed has a virtual destructor. In that case, the
   * `operator delete` that will be called is determined at runtime based on the
   * dynamic type of the object.
   */
  Function getDeallocator() {
    expr_deallocator(underlyingElement(this), unresolveElement(result), _)
  }

  /**
   * Holds if the deallocation function expects a size argument.
   */
  predicate hasSizedDeallocation() {
    exists(int form |
      expr_deallocator(underlyingElement(this), _, form) and
      form.bitAnd(1) != 0  // Bit zero is the "size" bit
    )
  }

  /**
   * Holds if the deallocation function expects an alignment argument.
   */
  predicate hasAlignedDeallocation() {
    exists(int form |
      expr_deallocator(underlyingElement(this), _, form) and
      form.bitAnd(2) != 0  // Bit one is the "alignment" bit
    )
  }

/**
   * Gets the call to a non-default `operator delete` that deallocates storage, if any.
   *
   * This will only be present when the type being deleted has a custom `operator delete`.
   */
  FunctionCall getAllocatorCall() { result = this.getChild(0) }

  /**
   * Gets the object being deleted.
   */
  Expr getExpr() { result = this.getChild(3) or result = this.getChild(1).getChild(-1) }
}

/**
 * A C++ `delete[]` (array) expression.
 */
class DeleteArrayExpr extends Expr, @delete_array_expr {
  override string toString() { result = "delete[]" }

  override int getPrecedence() { result = 15 }

  /**
   * Gets the element type of the array being deleted.
   */
  Type getDeletedElementType() {
    result = getExpr().getFullyConverted().getType().stripTopLevelSpecifiers().(PointerType).getBaseType()
  }

  /**
   * Gets the call to a destructor that occurs prior to the array's memory being deallocated, if any.
   *
   * At runtime, the destructor will be called once for each element in the array, but the
   * destructor call only exists once in the AST.
   */
  DestructorCall getDestructorCall() { result = this.getChild(1) }

  /**
   * Gets the destructor to be called to destroy each element in the array, if any.
   */
  Destructor getDestructor() { result = getDestructorCall().getTarget() }

  /**
   * Gets the `operator delete[]` that deallocates storage.
   */
  Function getDeallocator() {
    expr_deallocator(underlyingElement(this), unresolveElement(result), _)
  }

  /**
   * Holds if the deallocation function expects a size argument.
   */
  predicate hasSizedDeallocation() {
    exists(int form |
      expr_deallocator(underlyingElement(this), _, form) and
      form.bitAnd(1) != 0  // Bit zero is the "size" bit
    )
  }

  /**
   * Holds if the deallocation function expects an alignment argument.
   */
  predicate hasAlignedDeallocation() {
    exists(int form |
      expr_deallocator(underlyingElement(this), _, form) and
      form.bitAnd(2) != 0  // Bit one is the "alignment" bit
    )
  }

  /**
   * Gets the call to a non-default `operator delete` that deallocates storage, if any.
   *
   * This will only be present when the type being deleted has a custom `operator delete`.
   */
  FunctionCall getAllocatorCall() { result = this.getChild(0) }

  /**
   * Gets the array being deleted.
   */
  Expr getExpr() { result = this.getChild(3) or result = this.getChild(1).getChild(-1) }
}

/**
 * A compound statement enclosed in parentheses used as an expression (a GNU extension to C/C++).
 */
class StmtExpr extends Expr, @expr_stmt {
  override string toString() { result = "(statement expression)" }

  /**
   * Gets the statement enclosed by this `StmtExpr`.
   */
  Stmt getStmt() { result.getParent() = this }

  /**
   * Gets the result expression of the enclosed statement. For example,
   * `a+b` is the result expression in this example:
   *
   * ```
   * x = ({ dosomething(); a+b; });
   * ```
   */
  Expr getResultExpr() {
    result = getStmtResultExpr(getStmt())
  }
}

/** Get the result expression of a statement. (Helper function for StmtExpr.) */
private Expr getStmtResultExpr(Stmt stmt) {
  result = stmt.(ExprStmt).getExpr() or
  result = getStmtResultExpr(stmt.(Block).getLastStmt())
}

/**
 * A C/C++ this expression.
 */
class ThisExpr extends Expr, @thisaccess {
  override string toString() { result = "this" }

  override predicate mayBeImpure() {
    none()
  }
  override predicate mayBeGloballyImpure() {
    none()
  }
}

/**
 * A code block expression, for example `^ int (int x, int y) {return x + y;}`.
 *
 * Blocks are a language extension supported by Clang, and by Apple's
 * branch of GCC.
 */
class BlockExpr extends Literal {
  BlockExpr() {
    code_block(underlyingElement(this), _)
  }

  override string toString() { result = "^ { ... }" }

  /**
   * Gets the (anonymous) function associated with this code block expression.
   */
  Function getFunction() {
    code_block(underlyingElement(this), unresolveElement(result))
  }
}

/**
 * A C++11 `noexcept` expression, for example `noexcept(1 + 2)`.
 */
class NoExceptExpr extends Expr, @noexceptexpr {
  override string toString() { result = "noexcept(...)" }

  /**
   * Gets the expression inside this noexcept expression.
   */
  Expr getExpr() {
    result = this.getChild(0)
  }
}

/**
 * A C++17 fold expression. This will only appear in an uninstantiated template; any instantiations
 * of the template will instead contain the sequence of expressions given by expanding the fold.
 */
class FoldExpr extends Expr, @foldexpr {
  override string toString() {
    exists(string op |
      op = this.getOperatorString() and
      if this.isUnaryFold()
      then
        if this.isLeftFold()
        then result = "( ... " + op + " pack )"
        else result = "( pack " + op + " ... )"
      else
        if this.isLeftFold()
        then result = "( init " + op + " ... " + op + " pack )"
        else result = "( pack " + op + " ... " + op + " init )"
    )
  }

  /** Gets the binary operator used in this fold expression, as a string. */
  string getOperatorString() { fold(underlyingElement(this), result, _) }

  /** Holds if this is a left-fold expression. */
  predicate isLeftFold() { fold(underlyingElement(this), _, true) }

  /** Holds if this is a right-fold expression. */
  predicate isRightFold() { fold(underlyingElement(this), _, false) }

  /** Holds if this is a unary fold expression. */
  predicate isUnaryFold() { getNumChild() = 1 }

  /** Holds if this is a binary fold expression. */
  predicate isBinaryFold() { getNumChild() = 2 }

  /**
   * Gets the child expression containing the unexpanded parameter pack.
   */
  Expr getPackExpr() {
    this.isUnaryFold() and
    result = getChild(0)
    or
    this.isBinaryFold() and
    if this.isRightFold() then result = getChild(0) else result = getChild(1)
  }

  /**
   * If this is a binary fold, gets the expression representing the initial value.
   */
  Expr getInitExpr() {
    this.isBinaryFold() and
    if this.isRightFold() then result = getChild(1) else result = getChild(0)
  }
}

/**
 * Holds if `child` is the `n`th child of `parent` in an alternative syntax
 * tree that has `Conversion`s as part of the tree.
 */
private predicate convparents(Expr child, int idx, Element parent) {
  child.getConversion() = parent and
  idx = 0
  or
  exists(Expr astChild |
    exprparents(unresolveElement(astChild), idx, unresolveElement(parent)) and
    child = astChild.getFullyConverted()
  )
}

private predicate isStandardPlacementNewAllocator(Function operatorNew) {
  operatorNew.getName().matches("operator new%") and
  operatorNew.getNumberOfParameters() = 2 and
  operatorNew.getParameter(1).getType() instanceof VoidPointerType
}

// Pulled out for performance. See QL-796.
private predicate hasNoConversions(Expr e) { not e.hasConversion() }
