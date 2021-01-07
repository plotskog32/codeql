/**
 * Provides classes for working with functions, including template functions.
 */

import semmle.code.cpp.Location
import semmle.code.cpp.Class
import semmle.code.cpp.Parameter
import semmle.code.cpp.exprs.Call
import semmle.code.cpp.metrics.MetricFunction
import semmle.code.cpp.Linkage
private import semmle.code.cpp.internal.ResolveClass

/**
 * A C/C++ function [N4140 8.3.5]. Both member functions and non-member
 * functions are included. For example the function `MyFunction` in:
 * ```
 * void MyFunction() {
 *   DoSomething();
 * }
 * ```
 *
 * Function has a one-to-many relationship with FunctionDeclarationEntry,
 * because the same function can be declared in multiple locations. This
 * relationship between `Declaration` and `DeclarationEntry` is explained
 * in more detail in `Declaration.qll`.
 */
class Function extends Declaration, ControlFlowNode, AccessHolder, @function {
  override string getName() { functions(underlyingElement(this), result, _) }

  /**
   * DEPRECATED: Use `getIdentityString(Declaration)` from `semmle.code.cpp.Print` instead.
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
        if exists(getATemplateArgument())
        then
          templateArgs =
            "<" +
              concat(int i |
                exists(getTemplateArgument(i))
              |
                getTemplateArgument(i).toString(), ", " order by i
              ) + ">"
        else templateArgs = ""
      ) and
      args =
        "(" +
          concat(int i |
            exists(getParameter(i))
          |
            getParameter(i).getType().toString(), ", " order by i
          ) + ")"
    )
  }

  /** Gets a specifier of this function. */
  override Specifier getASpecifier() {
    funspecifiers(underlyingElement(this), unresolveElement(result)) or
    result.hasName(getADeclarationEntry().getASpecifier())
  }

  /** Gets an attribute of this function. */
  Attribute getAnAttribute() { funcattributes(underlyingElement(this), unresolveElement(result)) }

  /** Holds if this function is generated by the compiler. */
  predicate isCompilerGenerated() { compgenerated(underlyingElement(this)) }

  /** Holds if this function is inline. */
  predicate isInline() { this.hasSpecifier("inline") }

  /** Holds if this function is virtual. */
  predicate isVirtual() { this.hasSpecifier("virtual") }

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
  predicate isDeleted() { function_deleted(underlyingElement(this)) }

  /**
   * Holds if this function is explicitly defaulted with the `= default`
   * specifier.
   */
  predicate isDefaulted() { function_defaulted(underlyingElement(this)) }

  /**
   * Holds if this function is declared to be `constexpr`.
   *
   * Note that this does not hold if the function has been declared
   * `consteval`.
   */
  predicate isDeclaredConstexpr() { this.hasSpecifier("declared_constexpr") }

  /**
   * Holds if this function is `constexpr`. Normally, this holds if and
   * only if `isDeclaredConstexpr()` holds, but in some circumstances
   * they differ. For example, with
   * ```
   * int f(int i) { return 6; }
   * template <typename T> constexpr int g(T x) { return f(x); }
   * ```
   * `g<int>` is declared constexpr, but is not constexpr.
   *
   * Will also hold if this function is `consteval`.
   */
  predicate isConstexpr() { this.hasSpecifier("is_constexpr") }

  /**
   * Holds if this function is declared to be `consteval`.
   */
  predicate isConsteval() { this.hasSpecifier("is_consteval") }

  /**
   * Holds if this function is declared with `__attribute__((naked))` or
   * `__declspec(naked)`.
   */
  predicate isNaked() { getAnAttribute().hasName("naked") }

  /** Gets the return type of this function. */
  Type getType() { function_return_type(underlyingElement(this), unresolveElement(result)) }

  /**
   * Gets the return type of this function after specifiers have been deeply
   * stripped and typedefs have been resolved.
   */
  Type getUnspecifiedType() { result = getType().getUnspecifiedType() }

  /**
   * Gets the nth parameter of this function. There is no result for the
   * implicit `this` parameter, and there is no `...` varargs pseudo-parameter.
   */
  Parameter getParameter(int n) { params(unresolveElement(result), underlyingElement(this), n, _) }

  /**
   * Gets a parameter of this function. There is no result for the implicit
   * `this` parameter, and there is no `...` varargs pseudo-parameter.
   */
  Parameter getAParameter() { params(unresolveElement(result), underlyingElement(this), _, _) }

  /**
   * Gets an access of this function.
   *
   * To get calls to this function, use `getACallToThisFunction` instead.
   */
  FunctionAccess getAnAccess() { result.getTarget() = this }

  /**
   * Gets the number of parameters of this function, _not_ including any
   * implicit `this` parameter or any `...` varargs pseudo-parameter.
   */
  int getNumberOfParameters() { result = count(this.getAParameter()) }

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
    result = concat(int i | | min(getParameter(i).getTypedName()), ", " order by i)
  }

  /** Gets a call to this function. */
  FunctionCall getACallToThisFunction() { result.getTarget() = this }

  /**
   * Gets a declaration entry corresponding to this declaration. The
   * relationship between `Declaration` and `DeclarationEntry` is explained
   * in `Declaration.qll`.
   */
  override FunctionDeclarationEntry getADeclarationEntry() {
    if fun_decls(_, underlyingElement(this), _, _, _)
    then declEntry(result)
    else
      exists(Function f |
        this.isConstructedFrom(f) and
        fun_decls(unresolveElement(result), unresolveElement(f), _, _, _)
      )
  }

  private predicate declEntry(FunctionDeclarationEntry fde) {
    fun_decls(unresolveElement(fde), underlyingElement(this), _, _, _) and
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
  override Location getADeclarationLocation() { result = getADeclarationEntry().getLocation() }

  /** Holds if this Function is a Template specialization. */
  predicate isSpecialization() {
    exists(FunctionDeclarationEntry fde |
      fun_decls(unresolveElement(fde), underlyingElement(this), _, _, _) and
      fde.isSpecialization()
    )
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
    if exists(getDefinition())
    then result = getDefinition().getLocation()
    else exists(Function f | this.isConstructedFrom(f) and result = f.getDefinition().getLocation())
  }

  /**
   * Gets the preferred location of this declaration. (The location of the
   * definition, if possible.)
   */
  override Location getLocation() {
    if exists(getDefinition())
    then result = this.getDefinitionLocation()
    else result = this.getADeclarationLocation()
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
  BlockStmt getBlock() { result.getParentScope() = this }

  /** Holds if this function has an entry point. */
  predicate hasEntryPoint() { exists(getEntryPoint()) }

  /**
   * Gets the first node in this function's control flow graph.
   *
   * For most functions, this first node will be the `BlockStmt` returned by
   * `getBlock`. However in C++, the first node can also be a
   * `FunctionTryStmt`.
   */
  Stmt getEntryPoint() { function_entry_point(underlyingElement(this), unresolveElement(result)) }

  /**
   * Gets the metric class. `MetricFunction` has methods for computing
   * various metrics, such as "number of lines of code" and "number of
   * function calls".
   */
  MetricFunction getMetrics() { result = this }

  /** Holds if this function calls the function `f`. */
  predicate calls(Function f) { exists(Locatable l | this.calls(f, l)) }

  /**
   * Holds if this function calls the function `f` in the `FunctionCall`
   * expression `l`.
   */
  predicate calls(Function f, Locatable l) {
    exists(FunctionCall call |
      call.getEnclosingFunction() = this and call.getTarget() = f and call = l
    )
    or
    exists(DestructorCall call |
      call.getEnclosingFunction() = this and call.getTarget() = f and call = l
    )
  }

  /** Holds if this function accesses a function or variable or enumerator `a`. */
  predicate accesses(Declaration a) { exists(Locatable l | this.accesses(a, l)) }

  /**
   * Holds if this function accesses a function or variable or enumerator `a`
   * in the `Access` expression `l`.
   */
  predicate accesses(Declaration a, Locatable l) {
    exists(Access access |
      access.getEnclosingFunction() = this and
      a = access.getTarget() and
      access = l
    )
  }

  /** Gets a variable that is written-to in this function. */
  Variable getAWrittenVariable() {
    exists(ConstructorFieldInit cfi |
      cfi.getEnclosingFunction() = this and result = cfi.getTarget()
    )
    or
    exists(VariableAccess va |
      va = result.getAnAccess() and
      va.isUsedAsLValue() and
      va.getEnclosingFunction() = this
    )
  }

  /**
   * Implements `ControlFlowNode.getControlFlowScope`. The `Function` is
   * used to represent the exit node of the control flow graph, so it is
   * its own scope.
   */
  override Function getControlFlowScope() { result = this }

  /**
   * Implements `ControlFlowNode.getEnclosingStmt`. The `Function` is
   * used to represent the exit node of the control flow graph, so it
   * has no enclosing statement.
   */
  override Stmt getEnclosingStmt() { none() }

  /**
   * Holds if this function has C linkage, as specified by one of its
   * declaration entries. For example: `extern "C" void foo();`.
   */
  predicate hasCLinkage() { getADeclarationEntry().hasCLinkage() }

  /**
   * Holds if this function is constructed from `f` as a result
   * of template instantiation. If so, it originates either from a template
   * function or from a function nested in a template class.
   */
  predicate isConstructedFrom(Function f) {
    function_instantiation(underlyingElement(this), unresolveElement(f))
  }

  /**
   * Holds if this function is defined in several files. This is illegal in
   * C (though possible in some C++ compilers), and likely indicates that
   * several functions that are not linked together have been compiled. An
   * example would be a project with many 'main' functions.
   */
  predicate isMultiplyDefined() { strictcount(getFile()) > 1 }

  /** Holds if this function is a varargs function. */
  predicate isVarargs() { hasSpecifier("varargs") }

  /** Gets a type that is specified to be thrown by the function. */
  Type getAThrownType() { result = getADeclarationEntry().getAThrownType() }

  /**
   * Gets the `i`th type specified to be thrown by the function.
   */
  Type getThrownType(int i) { result = getADeclarationEntry().getThrownType(i) }

  /** Holds if the function has an exception specification. */
  predicate hasExceptionSpecification() { getADeclarationEntry().hasExceptionSpecification() }

  /** Holds if this function has a `throw()` exception specification. */
  predicate isNoThrow() { getADeclarationEntry().isNoThrow() }

  /** Holds if this function has a `noexcept` exception specification. */
  predicate isNoExcept() { getADeclarationEntry().isNoExcept() }

  /**
   * Gets a function that overloads this one.
   *
   * Note: if _overrides_ are wanted rather than _overloads_ then
   * `MemberFunction::getAnOverridingFunction` should be used instead.
   */
  Function getAnOverload() {
    (
      // If this function is declared in a class, only consider other
      // functions from the same class.
      exists(string name, Class declaringType |
        candGetAnOverloadMember(name, declaringType, this) and
        candGetAnOverloadMember(name, declaringType, result)
      )
      or
      // Conversely, if this function is not
      // declared in a class, only consider other functions not declared in a
      // class.
      exists(string name, Namespace namespace |
        candGetAnOverloadNonMember(name, namespace, this) and
        candGetAnOverloadNonMember(name, namespace, result)
      )
    ) and
    result != this and
    // Instantiations and specializations don't participate in overload
    // resolution.
    not (
      this instanceof FunctionTemplateInstantiation or
      result instanceof FunctionTemplateInstantiation
    ) and
    not (
      this instanceof FunctionTemplateSpecialization or
      result instanceof FunctionTemplateSpecialization
    )
  }

  /** Gets a link target which compiled or referenced this function. */
  LinkTarget getALinkTarget() { this = result.getAFunction() }

  /**
   * Holds if this function is side-effect free (conservative
   * approximation).
   */
  predicate isSideEffectFree() { not this.mayHaveSideEffects() }

  /**
   * Holds if this function may have side-effects; if in doubt, we assume it
   * may.
   */
  predicate mayHaveSideEffects() {
    // If we cannot see the definition then we assume that it may have
    // side-effects.
    if exists(this.getEntryPoint())
    then
      // If it might be globally impure (we don't care about it modifying
      // temporaries) then it may have side-effects.
      this.getEntryPoint().mayBeGloballyImpure()
      or
      // Constructor initializers are separate from the entry point ...
      this.(Constructor).getAnInitializer().mayBeGloballyImpure()
      or
      // ... and likewise for destructors.
      this.(Destructor).getADestruction().mayBeGloballyImpure()
    else
      // Unless it's a function that we know is side-effect-free, it may
      // have side-effects.
      not this.hasGlobalOrStdName([
          "strcmp", "wcscmp", "_mbscmp", "strlen", "wcslen", "_mbslen", "_mbslen_l", "_mbstrlen",
          "_mbstrlen_l", "strnlen", "strnlen_s", "wcsnlen", "wcsnlen_s", "_mbsnlen", "_mbsnlen_l",
          "_mbstrnlen", "_mbstrnlen_l", "strncmp", "wcsncmp", "_mbsncmp", "_mbsncmp_l", "strchr",
          "memchr", "wmemchr", "memcmp", "wmemcmp", "_memicmp", "_memicmp_l", "feof", "isdigit",
          "isxdigit", "abs", "fabs", "labs", "floor", "ceil", "atoi", "atol", "atoll", "atof"
        ])
  }

  /**
   * Gets the nearest enclosing AccessHolder.
   */
  override AccessHolder getEnclosingAccessHolder() { result = this.getDeclaringType() }
}

pragma[noinline]
private predicate candGetAnOverloadMember(string name, Class declaringType, Function f) {
  f.getName() = name and
  f.getDeclaringType() = declaringType
}

pragma[noinline]
private predicate candGetAnOverloadNonMember(string name, Namespace namespace, Function f) {
  f.getName() = name and
  f.getNamespace() = namespace and
  not exists(f.getDeclaringType())
}

/**
 * A particular declaration or definition of a C/C++ function. For example the
 * declaration and definition of `MyFunction` in the following code are each a
 * `FunctionDeclarationEntry`:
 * ```
 * void MyFunction();
 *
 * void MyFunction() {
 *   DoSomething();
 * }
 * ```
 */
class FunctionDeclarationEntry extends DeclarationEntry, @fun_decl {
  /** Gets the function which is being declared or defined. */
  override Function getDeclaration() { result = getFunction() }

  override string getAPrimaryQlClass() { result = "FunctionDeclarationEntry" }

  /** Gets the function which is being declared or defined. */
  Function getFunction() { fun_decls(underlyingElement(this), unresolveElement(result), _, _, _) }

  /** Gets the name of the function. */
  override string getName() { fun_decls(underlyingElement(this), _, _, result, _) }

  /**
   * Gets the return type of the function which is being declared or
   * defined.
   */
  override Type getType() { fun_decls(underlyingElement(this), _, unresolveElement(result), _, _) }

  /** Gets the location of this declaration entry. */
  override Location getLocation() { fun_decls(underlyingElement(this), _, _, _, result) }

  /** Gets a specifier associated with this declaration entry. */
  override string getASpecifier() { fun_decl_specifiers(underlyingElement(this), result) }

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
    fun_decl_typedef_type(underlyingElement(this), unresolveElement(result))
  }

  /**
   * Gets the cyclomatic complexity of this function:
   *
   *   The number of branching statements (if, while, do, for, switch,
   *   case, catch) plus the number of branching expressions (`?`, `&&`,
   *   `||`) plus one.
   */
  int getCyclomaticComplexity() { result = 1 + cyclomaticComplexityBranches(getBlock()) }

  /**
   * If this is a function definition, get the block containing the
   * function body.
   */
  BlockStmt getBlock() {
    this.isDefinition() and
    result = getFunction().getBlock() and
    result.getFile() = this.getFile()
  }

  /**
   * If this is a function definition, get the number of lines of code
   * associated with it.
   */
  pragma[noopt]
  int getNumberOfLines() {
    exists(BlockStmt b, Location l, int start, int end, int diff | b = getBlock() |
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
    param_decl_bind(unresolveElement(result), n, underlyingElement(this))
  }

  /** Gets the number of parameters of this function declaration. */
  int getNumberOfParameters() { result = count(this.getAParameterDeclarationEntry()) }

  /**
   * Gets a string representing the parameters of this function declaration.
   *
   * For example: for a function 'int Foo(int p1, int p2)' this would
   * return 'int p1, int p2'.
   */
  string getParameterString() {
    result = concat(int i | | min(getParameterDeclarationEntry(i).getTypedName()), ", " order by i)
  }

  /**
   * Holds if this declaration entry specifies C linkage:
   *
   *    `extern "C" void foo();`
   */
  predicate hasCLinkage() { getASpecifier() = "c_linkage" }

  /** Holds if this declaration entry has a void parameter list. */
  predicate hasVoidParamList() { getASpecifier() = "void_param_list" }

  /** Holds if this declaration is also a definition of its function. */
  override predicate isDefinition() { fun_def(underlyingElement(this)) }

  /** Holds if this declaration is a Template specialization. */
  predicate isSpecialization() { fun_specialized(underlyingElement(this)) }

  /**
   * Holds if this declaration is an implicit function declaration, that is,
   * where a function is used before it is declared (under older C standards).
   */
  predicate isImplicit() { fun_implicit(underlyingElement(this)) }

  /** Gets a type that is specified to be thrown by the declared function. */
  Type getAThrownType() { result = getThrownType(_) }

  /**
   * Gets the `i`th type specified to be thrown by the declared function
   * (where `i` is indexed from 0). For example, if a function is declared
   * to `throw(int,float)`, then the thrown type with index 0 would be
   * `int`, and that with index 1 would be `float`.
   */
  Type getThrownType(int i) {
    fun_decl_throws(underlyingElement(this), i, unresolveElement(result))
  }

  /**
   * If this declaration has a noexcept-specification [N4140 15.4], then
   * this predicate returns the argument to `noexcept` if one was given.
   */
  Expr getNoExceptExpr() { fun_decl_noexcept(underlyingElement(this), unresolveElement(result)) }

  /**
   * Holds if the declared function has an exception specification [N4140
   * 15.4].
   */
  predicate hasExceptionSpecification() {
    fun_decl_throws(underlyingElement(this), _, _) or
    fun_decl_noexcept(underlyingElement(this), _) or
    isNoThrow() or
    isNoExcept()
  }

  /**
   * Holds if the declared function has a `throw()` exception specification.
   */
  predicate isNoThrow() { fun_decl_empty_throws(underlyingElement(this)) }

  /**
   * Holds if the declared function has an empty `noexcept` exception
   * specification.
   */
  predicate isNoExcept() { fun_decl_empty_noexcept(underlyingElement(this)) }
}

/**
 * A C/C++ non-member function (a function that is not a member of any
 * class). For example the in the following code, `MyFunction` is a
 * `TopLevelFunction` but `MyMemberFunction` is not:
 * ```
 * void MyFunction() {
 *   DoSomething();
 * }
 *
 * class MyClass {
 * public:
 *   void MyMemberFunction() {
 *     DoSomething();
 *   }
 * };
 * ```
 */
class TopLevelFunction extends Function {
  TopLevelFunction() { not this.isMember() }

  override string getAPrimaryQlClass() { result = "TopLevelFunction" }
}

/**
 * A C++ user-defined operator [N4140 13.5].
 */
class Operator extends Function {
  Operator() { functions(underlyingElement(this), _, 5) }

  override string getAPrimaryQlClass() {
    not this instanceof MemberFunction and result = "Operator"
  }
}

/**
 * A C++ function which has a non-empty template argument list. For example
 * the function `myTemplateFunction` in the following code:
 * ```
 * template<class T>
 * void myTemplateFunction(T t) {
 *   ...
 * }
 * ```
 *
 * This comprises function declarations which are immediately preceded by
 * `template <...>`, where the "..." part is not empty, and therefore it does
 * not include:
 *
 *   1. Full specializations of template functions, as they have an empty
 *      template argument list.
 *   2. Instantiations of template functions, as they don't have an
 *      explicit template argument list.
 *   3. Member functions of template classes - unless they have their own
 *      (non-empty) template argument list.
 */
class TemplateFunction extends Function {
  TemplateFunction() {
    is_function_template(underlyingElement(this)) and exists(getATemplateArgument())
  }

  override string getAPrimaryQlClass() { result = "TemplateFunction" }

  /**
   * Gets a compiler-generated instantiation of this function template.
   */
  Function getAnInstantiation() {
    result.isConstructedFrom(this) and
    not result.isSpecialization()
  }

  /**
   * Gets a full specialization of this function template.
   *
   * Note that unlike classes, functions overload rather than specialize
   * partially. Therefore this does not include things which "look like"
   * partial specializations, nor does it include full specializations of
   * such things -- see FunctionTemplateSpecialization for further details.
   */
  FunctionTemplateSpecialization getASpecialization() { result.getPrimaryTemplate() = this }
}

/**
 * A function that is an instantiation of a template. For example
 * the instantiation `myTemplateFunction<int>` in the following code:
 * ```
 * template<class T>
 * void myTemplateFunction(T t) {
 *   ...
 * }
 *
 * void caller(int i) {
 *   myTemplateFunction<int>(i);
 * }
 * ```
 */
class FunctionTemplateInstantiation extends Function {
  TemplateFunction tf;

  FunctionTemplateInstantiation() { tf.getAnInstantiation() = this }

  override string getAPrimaryQlClass() { result = "FunctionTemplateInstantiation" }

  /**
   * Gets the function template from which this instantiation was instantiated.
   *
   * Example: For `int const& std::min<int>(int const&, int const&)`, returns `T const& min<T>(T const&, T const&)`.
   */
  TemplateFunction getTemplate() { result = tf }
}

/**
 * An explicit specialization of a C++ function template. For example the
 * function `myTemplateFunction<int>` in the following code:
 * ```
 * template<class T>
 * void myTemplateFunction(T t) {
 *   ...
 * }
 *
 * template<>
 * void myTemplateFunction<int>(int i) {
 *   ...
 * }
 * ```
 *
 * Note that unlike classes, functions overload rather than specialize
 * partially. Therefore this only includes the last two of the following
 * four definitions, and in particular does not include the second one:
 *
 * ```
 * template <typename T> void f(T) {...}
 * template <typename T> void f(T*) {...}
 * template <> void f<int>(int *) {...}
 * template <> void f<int*>(int *) {...}
 * ```
 *
 * Furthermore, this does not include compiler-generated instantiations of
 * function templates.
 *
 * For further reference on function template specializations, see:
 *   http://www.gotw.ca/publications/mill17.htm
 */
class FunctionTemplateSpecialization extends Function {
  FunctionTemplateSpecialization() { this.isSpecialization() }

  override string getAPrimaryQlClass() { result = "FunctionTemplateSpecialization" }

  /**
   * Gets the primary template for the specialization (the function template
   * this specializes).
   */
  TemplateFunction getPrimaryTemplate() { this.isConstructedFrom(result) }
}

/**
 * A GCC built-in function. For example: `__builtin___memcpy_chk`.
 */
class BuiltInFunction extends Function {
  BuiltInFunction() { functions(underlyingElement(this), _, 6) }

  /** Gets a dummy location for the built-in function. */
  override Location getLocation() {
    suppressUnusedThis(this) and
    result instanceof UnknownDefaultLocation
  }
}

private predicate suppressUnusedThis(Function f) { any() }
