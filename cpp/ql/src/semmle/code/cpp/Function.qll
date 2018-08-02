import semmle.code.cpp.Location
import semmle.code.cpp.Member
import semmle.code.cpp.Class
import semmle.code.cpp.Parameter
import semmle.code.cpp.exprs.Call
import semmle.code.cpp.metrics.MetricFunction
import semmle.code.cpp.Linkage
private import semmle.code.cpp.internal.Type

/**
 * A C/C++ function [N4140 8.3.5]. Both member functions and non-member
 * functions are included.
 *
 * Function has a one-to-many relationship with FunctionDeclarationEntry,
 * because the same function can be declared in multiple locations. This
 * relationship between `Declaration` and `DeclarationEntry` is explained
 * in more detail in `Declaration.qll`.
 */
class Function extends Declaration, ControlFlowNode, AccessHolder, @function {

  /**
   * Gets the name of this function.
   *
   * This name doesn't include a namespace or any argument types, so both
   * `::open()` and `::std::ifstream::open(...)` have the same name.
   *
   * To get the name including the namespace, use `getQualifiedName` or
   * `hasQualifiedName`.
   *
   * To test whether a function has a particular name in the global
   * namespace, use `hasGlobalName`.
   */
  override string getName() { functions(this,result,_) }

  /**
   * Gets the full signature of this function, including return type, parameter
   * types, and template arguments.
   *
   * For example, in the following code:
   * ```
   * template<typename T> T min(T x, T y);
   * int z = min(5, 7);
   * ```
   * The full signature of the function called on the last line would be
   * "min<int>(int, int) -> int", and the full signature of the uninstantiated
   * template on the first line would be "min<T>(T, T) -> T".
   */
  string getFullSignature() {
    exists(string name, string templateArgs, string args |
      result = name + templateArgs + args + " -> " + getType().toString() and
      name = getQualifiedName() and
      (
        if exists(getATemplateArgument()) then (
          templateArgs = "<" +
            concat(int i |
              exists(getTemplateArgument(i)) |
              getTemplateArgument(i).toString(), ", " order by i
            ) + ">"
        )
        else
          templateArgs = ""
      ) and
      args = "(" +
        concat(int i |
          exists(getParameter(i)) |
          getParameter(i).getType().toString(), ", " order by i
        ) + ")"
     )
  }

  /** Gets a specifier of this function. */
  override Specifier getASpecifier() {
    funspecifiers(this,result)
    or result.hasName(getADeclarationEntry().getASpecifier())
  }

  /** Gets an attribute of this function. */
  Attribute getAnAttribute() { funcattributes(this, result) }

  /** Holds if this function is generated by the compiler. */
  predicate isCompilerGenerated() {
    compgenerated(this)
  }

  /** Holds if this function is inline. */
  predicate isInline() {
    this.hasSpecifier("inline")
  }

  /** Holds if this function is virtual. */
  predicate isVirtual() {
    this.hasSpecifier("virtual")
  }

  /**
   * Holds if this function is deleted.
   * This may be because it was explicitly deleted with an `= delete`
   * definition, or because the compiler was unable to auto-generate a
   * definition for it.
   *
   * Most implicitly deleted functions are omitted from the database.
   * `Class.implicitCopyConstructorDeleted` and
   * `Class.implicitCopyAssignmentOperatorDeleted` can be used to find
   * whether a class would have had those members implicitly deleted.
   */
  predicate isDeleted() {
    function_deleted(this)
  }

  /**
   * Holds if this function is explicitly defaulted with the `= default`
   * specifier.
   */
  predicate isDefaulted() {
    function_defaulted(this)
  }

  /**
   * Holds if this function is declared with `__attribute__((naked))` or
   * `__declspec(naked)`.
   */
  predicate isNaked() {
    getAnAttribute().hasName("naked")
  }

  /** Gets the return type of this function. */
  Type getType() { function_return_type(this,unresolve(result)) }

  /** Gets the nth parameter of this function. */
  Parameter getParameter(int n) { params(result,this,n,_) }

  /** Gets a parameter of this function. */
  Parameter getAParameter() { params(result,this,_,_) }

  /**
   * Gets the number of parameters of this function, _not_ including any
   * implicit `this` parameter or any `...` varargs pseudo-parameter.
   */
  int getNumberOfParameters() {
     result = count(this.getAParameter())
  }

  /**
   * Gets the number of parameters of this function, _including_ any implicit
   * `this` parameter but _not_ including any `...` varargs pseudo-parameter.
   */
  int getEffectiveNumberOfParameters() {
    // This method is overridden in `MemberFunction`, where the result is
    // adjusted to account for the implicit `this` parameter.
    result = getNumberOfParameters()
  }

  /**
   * Gets a string representing the parameters of this function.
   *
   * For example: for a function `int Foo(int p1, int p2)` this would
   * return `int p1, int p2`.
   */
  string getParameterString() {
    result = getParameterStringFrom(0)
  }

  private string getParameterStringFrom(int index) {
    (
      index = getNumberOfParameters() and
      result = ""
    ) or (
      index = getNumberOfParameters() - 1 and
      result = getParameter(index).getTypedName()
    ) or (
      index < getNumberOfParameters() - 1 and
      result = getParameter(index).getTypedName() + ", " + getParameterStringFrom(index + 1)
    )
  }

  FunctionCall getACallToThisFunction() {
    result.getTarget() = this
  }

  /**
   * Gets a declaration entry corresponding to this declaration. The
   * relationship between `Declaration` and `DeclarationEntry` is explained
   * in `Declaration.qll`.
   */
  override FunctionDeclarationEntry getADeclarationEntry() {
    if fun_decls(_,this,_,_,_) then
      declEntry(result)
    else
      exists(Function f | this.isConstructedFrom(f) and fun_decls(result,f,_,_,_))
  }

  private predicate declEntry(FunctionDeclarationEntry fde) {
    fun_decls(fde,this,_,_,_) and
    // If one .cpp file specializes a function, and another calls the
    // specialized function, then when extracting the second we only see an
    // instantiation, not the specialization. We Therefore need to ignore
    // any non-specialized declarations if there are any specialized ones.
    (this.isSpecialization() implies fde.isSpecialization())
  }

  /**
   * Gets the location of a `FunctionDeclarationEntry` corresponding to this
   * declaration.
   */
  override Location getADeclarationLocation() {
    result = getADeclarationEntry().getLocation()
  }

  /** Holds if this Function is a Template specialization. */
  predicate isSpecialization() {
    exists(FunctionDeclarationEntry fde | fun_decls(fde,this,_,_,_)
                                      and fde.isSpecialization())
  }

  /**
   * Gets the declaration entry corresponding to this declaration that is a
   * definition, if any.
   */
  override FunctionDeclarationEntry getDefinition() {
    result = getADeclarationEntry() and
    result.isDefinition()
  }

  /** Gets the location of the definition, if any. */
  override Location getDefinitionLocation() {
    if exists(getDefinition()) then
      result = getDefinition().getLocation()
    else
      exists(Function f | this.isConstructedFrom(f) and result = f.getDefinition().getLocation())
  }

  /**
   * Gets the preferred location of this declaration. (The location of the
   * definition, if possible.)
   */
  override Location getLocation() {
    if exists(getDefinition()) then
      result = this.getDefinitionLocation()
    else
      result = this.getADeclarationLocation()
  }

  /** Gets a child declaration of this function. */
  Declaration getADeclaration() { result = this.getAParameter() }

  /**
   * Gets the block that is the function body.
   *
   * For C++ functions whose body is a function try statement rather than a
   * block, this gives the block guarded by the try statement. See
   * `FunctionTryStmt` for further information.
   */
  Block getBlock() { result.getParentScope() = this }

  /** Holds if this function has an entry point. */
  predicate hasEntryPoint() { exists(getEntryPoint()) }

  /**
   * Gets the first node in this function's control flow graph.
   *
   * For most functions, this first node will be the `Block` returned by
   * `getBlock`. However in C++, the first node can also be a
   * `FunctionTryStmt`.
   */
  Stmt getEntryPoint() {
    function_entry_point(this, result)
  }

  /**
   * Gets the metric class. `MetricFunction` has methods for computing
   * various metrics, such as "number of lines of code" and "number of
   * function calls".
   */
  MetricFunction getMetrics() { result = this }

  /** Holds if this function calls the function `f`. */
  predicate calls(Function f) {
    exists(Locatable l | this.calls(f, l))
  }

  /**
   * Holds if this function calls the function `f` in the `FunctionCall`
   * expression `l`.
   */
  predicate calls(Function f, Locatable l) {
    exists(FunctionCall call | call.getEnclosingFunction() = this and call.getTarget() = f and call = l)
    or exists(DestructorCall call | call.getEnclosingFunction() = this and call.getTarget() = f and call = l)
  }

  /** Holds if this function accesses a function or variable or enumerator `a`. */
  predicate accesses(Declaration a) {
    exists(Locatable l | this.accesses(a, l))
  }

  /**
   * Holds if this function accesses a function or variable or enumerator `a`
   * in the `Access` expression `l`.
   */
  predicate accesses(Declaration a, Locatable l) {
    exists(Access access | access.getEnclosingFunction() = this and
      a = access.getTarget() and access = l)
  }

  /** Gets a variable that is written-to in this function. */
  Variable getAWrittenVariable() {
    exists(ConstructorFieldInit cfi | cfi.getEnclosingFunction() = this and result = cfi.getTarget()) or
    exists(VariableAccess va | va = result.getAnAccess() and
                               va.isUsedAsLValue() and
                               va.getEnclosingFunction() = this)
  }

  /**
   * Implements `ControlFlowNode.getControlFlowScope`. The `Function` is
   * used to represent the exit node of the control flow graph, so it is
   * its own scope.
   */
  override Function getControlFlowScope() {
    result = this
  }

  /**
   * Implements `ControlFlowNode.getEnclosingStmt`. The `Function` is
   * used to represent the exit node of the control flow graph, so it
   * has no enclosing statement.
   */
  override Stmt getEnclosingStmt() {
    none()
  }

  /**
   * Holds if this function has C linkage, as specified by one of its
   * declaration entries. For example: `extern "C" void foo();`.
   */
  predicate hasCLinkage() {
    getADeclarationEntry().hasCLinkage()
  }

  /**
   * Holds if this function is constructed from `f` as a result
   * of template instantiation. If so, it originates either from a template
   * function or from a function nested in a template class.
   */
  predicate isConstructedFrom(Function f) {
    function_instantiation(this, f)
  }

  /**
   * Gets an argument used to instantiate this class from a template
   * class.
   */
  Type getATemplateArgument() {
    exists(int i | this.getTemplateArgument(i) = result )
  }

  /**
   * Gets a particular argument used to instantiate this class from a
   * template class.
   */
  Type getTemplateArgument(int index) {
    function_template_argument(this,index,unresolve(result))
  }

  /**
   * Holds if this function is defined in several files. This is illegal in
   * C (though possible in some C++ compilers), and likely indicates that
   * several functions that are not linked together have been compiled. An
   * example would be a project with many 'main' functions.
   */
  predicate isMultiplyDefined() {
    strictcount(getFile()) > 1
  }

  /** Holds if this function is a varargs function. */
  predicate isVarargs() {
    hasSpecifier("varargs")
  }

  /** Gets a type that is specified to be thrown by the function. */
  Type getAThrownType() {
    result = getADeclarationEntry().getAThrownType()
  }

  /**
   * Gets the `i`th type specified to be thrown by the function.
   */
  Type getThrownType(int i) {
    result = getADeclarationEntry().getThrownType(i)
  }

  /** Holds if the function has an exception specification. */
  predicate hasExceptionSpecification() {
    getADeclarationEntry().hasExceptionSpecification()
  }

  /** Holds if this function has a `throw()` exception specification. */
  predicate isNoThrow() {
    getADeclarationEntry().isNoThrow()
  }

  /** Holds if this function has a `noexcept` exception specification. */
  predicate isNoExcept() {
    getADeclarationEntry().isNoExcept()
  }

  /** Gets a function that overloads this one. */
  Function getAnOverload() {
    result.getName() = getName()
    and result.getNamespace() = getNamespace()
    and result != this

    // If this function is declared in a class, only consider other
    // functions from the same class. Conversely, if this function is not
    // declared in a class, only consider other functions not declared in a
    // class.
    and
    (
      if exists(getDeclaringType()) then
        result.getDeclaringType() = getDeclaringType()
      else
        not exists(result.getDeclaringType())
    )

    // Instantiations and specializations don't participate in overload
    // resolution.
    and not (this instanceof FunctionTemplateInstantiation or
             result instanceof FunctionTemplateInstantiation)
    and not (this instanceof FunctionTemplateSpecialization or
             result instanceof FunctionTemplateSpecialization)
  }

  /** Gets a link target which compiled or referenced this function. */
  LinkTarget getALinkTarget() {
    this = result.getAFunction()
  }

  /**
   * Holds if this function is side-effect free (conservative
   * approximation).
   */
  predicate isSideEffectFree() {
    not this.mayHaveSideEffects()
  }

  /**
   * Holds if this function may have side-effects; if in doubt, we assume it
   * may.
   */
  predicate mayHaveSideEffects() {
    // If we cannot see the definition then we assume that it may have
    // side-effects.
    if exists(this.getEntryPoint()) then (
      // If it might be globally impure (we don't care about it modifying
      // temporaries) then it may have side-effects.
      this.getEntryPoint().mayBeGloballyImpure() or
      // Constructor initializers are separate from the entry point ...
      this.(Constructor).getAnInitializer().mayBeGloballyImpure() or
      // ... and likewise for destructors.
      this.(Destructor).getADestruction().mayBeGloballyImpure()
    ) else not exists(string name | this.hasGlobalName(name) |
      // Unless it's a function that we know is side-effect-free, it may
      // have side-effects.
      name = "strcmp" or name = "wcscmp" or name = "_mbscmp" or
      name = "strlen" or name = "wcslen" or
      name = "_mbslen" or name = "_mbslen_l" or
      name = "_mbstrlen" or name = "_mbstrlen_l" or
      name = "strnlen" or name = "strnlen_s" or
      name = "wcsnlen" or name = "wcsnlen_s" or
      name = "_mbsnlen" or name = "_mbsnlen_l" or
      name = "_mbstrnlen" or name = "_mbstrnlen_l" or
      name = "strncmp" or name = "wcsncmp" or
      name = "_mbsncmp" or name = "_mbsncmp_l" or
      name = "strchr" or name = "memchr" or name = "wmemchr" or
      name = "memcmp" or name = "wmemcmp" or
      name = "_memicmp" or name = "_memicmp_l" or
      name = "feof" or
      name = "isdigit" or name = "isxdigit" or
      name = "abs" or name = "fabs" or name = "labs" or
      name = "floor" or name = "ceil" or
      name = "atoi" or name = "atol" or name = "atoll" or name = "atof"
    )
  }

  /**
   * Gets the nearest enclosing AccessHolder.
   */
  override AccessHolder getEnclosingAccessHolder() {
    result = this.getDeclaringType()
  }
}

/**
 * A particular declaration or definition of a C/C++ function.
 */
class FunctionDeclarationEntry extends DeclarationEntry, @fun_decl {
  /** Gets the function which is being declared or defined. */
  override Function getDeclaration() { result = getFunction() }

  /** Gets the function which is being declared or defined. */
  Function getFunction() { fun_decls(this,result,_,_,_) }

  /** Gets the name of the function. */
  override string getName() { fun_decls(this,_,_,result,_) }

  /**
   * Gets the return type of the function which is being declared or
   * defined.
   */
  override Type getType() { fun_decls(this,_,unresolve(result),_,_) }

  /** Gets the location of this declaration entry. */
  override Location getLocation() { fun_decls(this,_,_,_,result) }

  /** Gets a specifier associated with this declaration entry. */
  override string getASpecifier() { fun_decl_specifiers(this,result) }

  /**
   * Implements `Element.getEnclosingElement`. A function declaration does
   * not have an enclosing element.
   */
  override Element getEnclosingElement() { none() }

  /**
   * Gets the typedef type (if any) used for this function declaration. As
   * an example, the typedef type in the declaration of function foo in the
   * following is Foo:
   *
   * typedef int Foo();
   * static Foo foo;
   */
  TypedefType getTypedefType() {
    fun_decl_typedef_type(this,result)
  }

  /**
   * Gets the cyclomatic complexity of this function:
   *
   *   The number of branching statements (if, while, do, for, switch,
   *   case, catch) plus the number of branching expressions (`?`, `&&`,
   *   `||`) plus one.
   */
  int getCyclomaticComplexity() {
    result = 1 + cyclomaticComplexityBranches(getBlock())
  }

  /**
   * If this is a function definition, get the block containing the
   * function body.
   */
  Block getBlock() {
    this.isDefinition() and
    result = getFunction().getBlock() and result.getFile() = this.getFile()
  }

  /**
   * If this is a function definition, get the number of lines of code
   * associated with it.
   */
  pragma[noopt] int getNumberOfLines() {
    exists(Block b, Location l, int start, int end, int diff| b = getBlock() |
      l = b.getLocation() and
      start = l.getStartLine() and
      end = l.getEndLine() and
      diff = end - start and
      result = diff + 1
    )
  }

  /**
   * Gets the declaration entry for a parameter of this function
   * declaration.
   */
  ParameterDeclarationEntry getAParameterDeclarationEntry() {
    result = getParameterDeclarationEntry(_)
  }

  /**
   * Gets the declaration entry for the nth parameter of this function
   * declaration.
   */
  ParameterDeclarationEntry getParameterDeclarationEntry(int n) {
    param_decl_bind(result,n,this)
  }

  /** Gets the number of parameters of this function declaration. */
  int getNumberOfParameters() {
     result = count(this.getAParameterDeclarationEntry())
  }

  /**
   * Gets a string representing the parameters of this function declaration.
   *
   * For example: for a function 'int Foo(int p1, int p2)' this would
   * return 'int p1, int p2'.
   */
  string getParameterString() {
    result = getParameterStringFrom(0)
  }

  private string getParameterStringFrom(int index) {
    (
      index = getNumberOfParameters() and
      result = ""
    ) or (
      index = getNumberOfParameters() - 1 and
      result = getParameterDeclarationEntry(index).getTypedName()
    ) or (
      index < getNumberOfParameters() - 1 and
      result = getParameterDeclarationEntry(index).getTypedName() + ", " + getParameterStringFrom(index + 1)
    )
  }

  /** Holds if this declaration entry specifies C linkage:
   *
   *    `extern "C" void foo();`
   */
  predicate hasCLinkage() {
    getASpecifier() = "c_linkage"
  }

  /** Holds if this declaration entry has a void parameter list. */
  predicate hasVoidParamList() {
    getASpecifier() = "void_param_list"
  }

  /** Holds if this declaration is also a definition of its function. */
  override predicate isDefinition() {
    fun_def(this)
  }

  /** Holds if this declaration is a Template specialization. */
  predicate isSpecialization() {
    fun_specialized(this)
  }

  /**
   * Holds if this declaration is an implicit function declaration, that is,
   * where a function is used before it is declared (under older C standards).
   */
  predicate isImplicit() {
    fun_implicit(this)
  }

  /** Gets a type that is specified to be thrown by the declared function. */
  Type getAThrownType() {
    result = getThrownType(_)
  }

  /**
   * Gets the `i`th type specified to be thrown by the declared function
   * (where `i` is indexed from 0). For example, if a function is declared
   * to `throw(int,float)`, then the thrown type with index 0 would be
   * `int`, and that with index 1 would be `float`.
   */
  Type getThrownType(int i) {
    fun_decl_throws(this,i,unresolve(result))
  }

  /**
   * If this declaration has a noexcept-specification [N4140 15.4], then
   * this predicate returns the argument to `noexcept` if one was given.
   */
  Expr getNoExceptExpr() {
    fun_decl_noexcept(this,result)
  }

  /**
   * Holds if the declared function has an exception specification [N4140
   * 15.4].
   */
  predicate hasExceptionSpecification() {
    fun_decl_throws(this,_,_) or
    fun_decl_noexcept(this,_) or
    isNoThrow() or
    isNoExcept()
  }

  /**
   * Holds if the declared function has a `throw()` exception specification.
   */
  predicate isNoThrow() {
    fun_decl_empty_throws(this)
  }

  /**
   * Holds if the declared function has an empty `noexcept` exception
   * specification.
   */
  predicate isNoExcept() {
    fun_decl_empty_noexcept(this)
  }
}


/**
 * A C/C++ non-member function (a function that is not a member of any
 * class).
 */
class TopLevelFunction extends Function {
  TopLevelFunction() {
    not this.isMember()
  }
}

/**
 * A C++ function declared as a member of a class [N4140 9.3]. This includes
 * static member functions.
 */
class MemberFunction extends Function {
  MemberFunction() {
    this.isMember()
  }

  /**
   * Gets the number of parameters of this function, including any implicit
   * `this` parameter.
   */
  override int getEffectiveNumberOfParameters() {
    if isStatic() then
      result = getNumberOfParameters()
    else
      result = getNumberOfParameters() + 1
  }

  /** Holds if this member is private. */
  predicate isPrivate() { this.hasSpecifier("private") }

  /** Holds if this member is protected. */
  predicate isProtected() { this.hasSpecifier("protected") }

  /** Holds if this member is public. */
  predicate isPublic() { this.hasSpecifier("public") }

  /** Holds if this function overrides that function. */
  predicate overrides(MemberFunction that) { overrides(this,that) }

  /** Gets a directly overridden function. */
  MemberFunction getAnOverriddenFunction() { this.overrides(result) }

  /** Gets a directly overriding function. */
  MemberFunction getAnOverridingFunction() { result.overrides(this) }

  /**
   * Gets the declaration entry for this member function that is within the
   * class body.
   */
  FunctionDeclarationEntry getClassBodyDeclarationEntry() {
    if strictcount(getADeclarationEntry()) = 1 then
      result = getDefinition()
    else
      (result = getADeclarationEntry() and result != getDefinition())
  }

}

/**
 * A C++ virtual function.
 */
class VirtualFunction extends MemberFunction {

  VirtualFunction() {
    this.hasSpecifier("virtual") or purefunctions(this)
  }

  /** Holds if this virtual function is pure. */
  predicate isPure() { this instanceof PureVirtualFunction }

  /**
   * Holds if this function was declared with the `override` specifier
   * [N4140 10.3].
   */
  predicate isOverrideExplicit() { this.hasSpecifier("override") }
}

/**
 * A C++ pure virtual function [N4140 10.4].
 */
class PureVirtualFunction extends VirtualFunction {

  PureVirtualFunction() { purefunctions(this) }

}

/**
 * A const C++ member function [N4140 9.3.1/4]. A const function does not
 * modify the state of its class.
 * For example: `int day() const { return d; }`
 */
class ConstMemberFunction extends MemberFunction {

  ConstMemberFunction() { this.hasSpecifier("const") }

}

/**
 * A C++ constructor [N4140 12.1].
 */
class Constructor extends MemberFunction {

  Constructor() { functions(this,_,2) }

  /**
   * Holds if this constructor serves as a default constructor.
   *
   * This holds for constructors with zero formal parameters. It also holds
   * for constructors which have a non-zero number of formal parameters,
   * provided that every parameter has a default value.
   */
  predicate isDefault() {
    forall(Parameter p | p = this.getAParameter() | p.hasInitializer())
  }

  /**
   * Gets an entry in the constructor's initializer list, or a
   * compiler-generated action which initializes a base class or member
   * variable.
   */
  ConstructorInit getAnInitializer() {
    result = getInitializer(_)
  }

  /**
   * Gets an entry in the constructor's initializer list, or a
   * compiler-generated action which initializes a base class or member
   * variable. The index specifies the order in which the initializer is
   * to be evaluated.
   */
  ConstructorInit getInitializer(int i) {
    exprparents(result, i, this)
  }
}

/** A function that defines an implicit conversion. */
abstract class ImplicitConversionFunction extends MemberFunction {
  abstract Type getSourceType();
  abstract Type getDestType();
}

/** A C++ constructor that also defines an implicit conversion. */
class ConversionConstructor extends Constructor, ImplicitConversionFunction {
  ConversionConstructor() {
    strictcount(Parameter p | p = getAParameter() and not p.hasInitializer()) = 1
    and not hasSpecifier("explicit")
    and not(this instanceof CopyConstructor)
  }

  /** Gets the type this `ConversionConstructor` takes as input. */
  override Type getSourceType() { result = this.getParameter(0).getType() }

  /** Gets the type this `ConversionConstructor` is a constructor of. */
  override Type getDestType()   { result = this.getDeclaringType() }
}

private predicate hasCopySignature(MemberFunction f) {
  f.getParameter(0).getType()
    .getUnderlyingType()                 // resolve typedefs
    .(LValueReferenceType).getBaseType() // step through lvalue reference type
    .getUnspecifiedType() =              // resolve typedefs, strip const/volatile
  f.getDeclaringType()
}

private predicate hasMoveSignature(MemberFunction f) {
  f.getParameter(0).getType()
    .getUnderlyingType()                 // resolve typedefs
    .(RValueReferenceType).getBaseType() // step through rvalue reference type
    .getUnspecifiedType() =              // resolve typedefs, strip const/volatile
  f.getDeclaringType()
}

/**
 * A C++ copy constructor, such as `T::T(const T&)` [N4140 12.8].
 *
 * As per the standard, a copy constructor of class T is a non-template
 * constructor whose first parameter has type `T&`, `const T&`, `volatile
 * T&`, or `const volatile T&`, and either there are no other parameters,
 * or the rest of the parameters all have default values.
 *
 * For template classes, it can generally not be determined until instantiation
 * whether a constructor is a copy constructor. For such classes, `CopyConstructor`
 * over-approximates the set of copy constructors; if an under-approximation is
 * desired instead, see the member predicate
 * `mayNotBeCopyConstructorInInstantiation`.
 */
class CopyConstructor extends Constructor {
  CopyConstructor() {
    hasCopySignature(this) and
    (
      // The rest of the parameters all have default values
      forall(int i | i > 0 and exists(getParameter(i)) |
        getParameter(i).hasInitializer()
      )
      or
      // or this is a template class, in which case the default values have
      // not been extracted even if they exist. In that case, we assume that
      // there are default values present since that is the most common case
      // in real-world code.
      getDeclaringType() instanceof TemplateClass
    ) and
    not exists(getATemplateArgument())
  }

  /**
   * Holds if we cannot determine that this constructor will become a copy
   * constructor in all instantiations. Depending on template parameters of the
   * enclosing class, this may become an ordinary constructor or a copy
   * constructor.
   */
  predicate mayNotBeCopyConstructorInInstantiation() {
    // In general, default arguments of template classes can only be
    // type-checked for each template instantiation; if an argument in an
    // instantiation fails to type-check then the corresponding parameter has
    // no default argument in the instantiation.
    getDeclaringType() instanceof TemplateClass and
    getNumberOfParameters() > 1
  }
}

/**
 * A C++ move constructor, such as `T::T(T&&)` [N4140 12.8].
 *
 * As per the standard, a move constructor of class T is a non-template
 * constructor whose first parameter is `T&&`, `const T&&`, `volatile T&&`,
 * or `const volatile T&&`, and either there are no other parameters, or
 * the rest of the parameters all have default values.
 *
 * For template classes, it can generally not be determined until instantiation
 * whether a constructor is a move constructor. For such classes, `MoveConstructor`
 * over-approximates the set of move constructors; if an under-approximation is
 * desired instead, see the member predicate
 * `mayNotBeMoveConstructorInInstantiation`.
 */
class MoveConstructor extends Constructor {
  MoveConstructor() {
    hasMoveSignature(this) and
    (
      // The rest of the parameters all have default values
      forall(int i | i > 0 and exists(getParameter(i)) |
        getParameter(i).hasInitializer()
      )
      or
      // or this is a template class, in which case the default values have
      // not been extracted even if they exist. In that case, we assume that
      // there are default values present since that is the most common case
      // in real-world code.
      getDeclaringType() instanceof TemplateClass
    ) and
    not exists(getATemplateArgument())
  }

  /**
   * Holds if we cannot determine that this constructor will become a move
   * constructor in all instantiations. Depending on template parameters of the
   * enclosing class, this may become an ordinary constructor or a move
   * constructor.
   */
  predicate mayNotBeMoveConstructorInInstantiation() {
    // In general, default arguments of template classes can only be
    // type-checked for each template instantiation; if an argument in an
    // instantiation fails to type-check then the corresponding parameter has
    // no default argument in the instantiation.
    getDeclaringType() instanceof TemplateClass and
    getNumberOfParameters() > 1
  }
}

/**
 * A C++ constructor that takes no arguments ('default' constructor). This
 * is the constructor that is invoked when no initializer is given.
 */
class NoArgConstructor extends Constructor {
  NoArgConstructor() {
    this.getNumberOfParameters() = 0
  }
}

/**
 * A C++ destructor [N4140 12.4].
 */
class Destructor extends MemberFunction {
  Destructor() { functions(this,_,3) }

  /**
   * Gets a compiler-generated action which destructs a base class or member
   * variable.
   */
  DestructorDestruction getADestruction() {
    result = getDestruction(_)
  }

  /**
   * Gets a compiler-generated action which destructs a base class or member
   * variable. The index specifies the order in which the destruction should
   * be evaluated.
   */
  DestructorDestruction getDestruction(int i) {
    exprparents(result, i, this)
  }
}

/**
 * A C++ conversion operator [N4140 12.3.2].
 */
class ConversionOperator extends MemberFunction, ImplicitConversionFunction {

  ConversionOperator() { functions(this,_,4) }

  override Type getSourceType() { result = this.getDeclaringType() }
  override Type getDestType() { result = this.getType() }

}

/**
 * A C++ user-defined operator [N4140 13.5].
 */
class Operator extends Function {

  Operator() { functions(this,_,5) }

}

/**
 * A C++ copy assignment operator, such as `T& T::operator=(const T&)`
 * [N4140 12.8].
 *
 * As per the standard, a copy assignment operator of class `T` is a
 * non-template non-static member function with the name `operator=` that
 * takes exactly one parameter of type `T`, `T&`, `const T&`, `volatile
 * T&`, or `const volatile T&`.
 */
class CopyAssignmentOperator extends Operator {
  CopyAssignmentOperator() {
    hasName("operator=") and
    (hasCopySignature(this) or
     // Unlike CopyConstructor, this member allows a non-reference
     // parameter.
     getParameter(0).getType().getUnspecifiedType() = getDeclaringType()
    ) and
    not exists(this.getParameter(1)) and
    not exists(getATemplateArgument())
  }
}


/**
 * A C++ move assignment operator, such as `T& T::operator=(T&&)` [N4140
 * 12.8].
 *
 * As per the standard, a move assignment operator of class `T` is a
 * non-template non-static member function with the name `operator=` that
 * takes exactly one parameter of type `T&&`, `const T&&`, `volatile T&&`,
 * or `const volatile T&&`.
 */
class MoveAssignmentOperator extends Operator {
  MoveAssignmentOperator() {
    hasName("operator=") and
    hasMoveSignature(this) and
    not exists(this.getParameter(1)) and
    not exists(getATemplateArgument())
  }
}


/**
 * A C++ function which has a non-empty template argument list.
 *
 * This includes function declarations which are immediately preceded by
 * `template <...>`, where the "..." part is not empty, and therefore it
 * does not include:
 *
 *   1. Full specializations of template functions, as they have an empty
 *      template argument list.
 *   2. Instantiations of template functions, as they don't have an
 *      explicit template argument list.
 *   3. Member functions of template classes - unless they have their own
 *      (non-empty) template argument list.
 */
class TemplateFunction extends Function {
  TemplateFunction() { is_function_template(this) and exists(getATemplateArgument()) }

  /**
   * Gets a compiler-generated instantiation of this function template.
   */
  Function getAnInstantiation() {
    result.isConstructedFrom(this)
    and not result.isSpecialization()
  }

  /**
   * Gets a full specialization of this function template.
   *
   * Note that unlike classes, functions overload rather than specialize
   * partially. Therefore this does not include things which "look like"
   * partial specializations, nor does it include full specializations of
   * such things -- see FunctionTemplateSpecialization for further details.
   */
  FunctionTemplateSpecialization getASpecialization() {
    result.getPrimaryTemplate() = this
  }
}

/**
 * A function that is an instantiation of a template.
 */
class FunctionTemplateInstantiation extends Function {
  FunctionTemplateInstantiation() {
    exists(TemplateFunction tf | tf.getAnInstantiation() = this)
  }
}

/**
 * An explicit specialization of a C++ function template.
 * For example: `template <> void f<int*>(int *)`.
 *
 * Note that unlike classes, functions overload rather than specialize
 * partially. Therefore this only includes the last two of the following
 * four definitions, and in particular does not include the second one:
 *
 *   ```
 *   template <typename T> void f(T) {...}
 *   template <typename T> void f(T*) {...}
 *   template <> void f<int>(int *) {...}
 *   template <> void f<int*>(int *) {...}
 *   ```
 *
 * Furthermore, this does not include compiler-generated instantiations of
 * function templates.
 *
 * For further reference on function template specializations, see:
 *   http://www.gotw.ca/publications/mill17.htm
 */
class FunctionTemplateSpecialization extends Function {
  FunctionTemplateSpecialization() {
    this.isSpecialization()
  }

  /**
   * Gets the primary template for the specialization (the function template
   * this specializes).
   */
  TemplateFunction getPrimaryTemplate() {
    this.isConstructedFrom(result)
  }
}

/**
 * A GCC built-in function. For example: `__builtin___memcpy_chk`.
 */
class BuiltInFunction extends Function {
  BuiltInFunction() {
    functions(this,_,6)
  }

  /** Gets a dummy location for the built-in function. */
  override Location getLocation() {
    suppressUnusedThis(this) and
    result instanceof UnknownDefaultLocation
  }
}

private predicate suppressUnusedThis(Function f) { any() }
