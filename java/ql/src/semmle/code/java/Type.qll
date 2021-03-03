/**
 * Provides classes and predicates for working with Java types.
 *
 * Types can be primitive types (`PrimitiveType`), array types (`Array`), or reference
 * types (`RefType`), where the latter are either classes (`Class`) or interfaces
 * (`Interface`).
 *
 * Reference types can be at the top level (`TopLevelType`) or nested (`NestedType`).
 * Classes can also be local (`LocalClass`) or anonymous (`AnonymousClass`).
 * Enumerated types (`EnumType`) are a special kind of class.
 */

import Member
import Modifier
import JDK

/**
 * Holds if reference type `t` is an immediate super-type of `sub`.
 */
cached
predicate hasSubtype(RefType t, Type sub) {
  // Direct subtype.
  extendsReftype(sub, t) and t != sub
  or
  implInterface(sub, t)
  or
  // A parameterized type `T<A>` is a subtype of the corresponding raw type `T<>`.
  parSubtypeRaw(t, sub) and t != sub
  or
  // Array subtyping is covariant.
  arraySubtype(t, sub) and t != sub
  or
  // Type parameter containment for parameterized types.
  parContainmentSubtype(t, sub) and t != sub
  or
  // Type variables are subtypes of their upper bounds.
  typeVarSubtypeBound(t, sub) and t != sub
}

private predicate typeVarSubtypeBound(RefType t, TypeVariable tv) {
  if tv.hasTypeBound() then t = tv.getATypeBound().getType() else t instanceof TypeObject
}

private predicate parSubtypeRaw(RefType t, ParameterizedType sub) {
  t = sub.getErasure().(GenericType).getRawType()
}

private predicate arraySubtype(Array sup, Array sub) {
  hasSubtype(sup.getComponentType(), sub.getComponentType())
}

/*
 * `parContainmentSubtype(pt, psub)` is equivalent to:
 * ```
 * pt != psub and
 * pt.getGenericType() = psub.getGenericType() and
 * forex(int i | i in [0..pt.getNumberOfTypeArguments()-1] |
 *   typeArgumentContains(_, pt.getTypeArgument(i), psub.getTypeArgument(i), _)
 * )
 * ```
 * For performance several transformations are made. First, the `forex` is
 * written as a loop where `typeArgumentsContain(_, pt, psub, n)` encode that
 * the `forex` holds for `i in [0..n]`. Second, the relation is split into two
 * cases depending on whether `pt.getNumberOfTypeArguments()` is 1 or 2+, as
 * this allows us to unroll the loop and collapse the first two iterations. The
 * base case for `typeArgumentsContain` is therefore `n=1` and this allows an
 * improved join order implemented by `contains01`.
 */

private predicate parContainmentSubtype(ParameterizedType pt, ParameterizedType psub) {
  pt != psub and
  typeArgumentsContain(_, pt, psub, pt.getNumberOfTypeArguments() - 1)
  or
  typeArgumentsContain0(_, pt, psub)
}

/**
 * Gets the `index`-th type parameter of `t`, which is a parameterization of `g`.
 */
private RefType parameterisationTypeArgument(GenericType g, ParameterizedType t, int index) {
  g = t.getGenericType() and
  result = t.getTypeArgument(index)
}

private predicate varianceCandidate(ParameterizedType pt) {
  pt.getATypeArgument() instanceof Wildcard
}

pragma[noinline]
private RefType parameterisationTypeArgumentVarianceCand(
  GenericType g, ParameterizedType t, int index
) {
  result = parameterisationTypeArgument(g, t, index) and
  varianceCandidate(t)
}

/**
 * Holds if every type argument of `s` (up to `n` with `n >= 1`) contains the
 * corresponding type argument of `t`. Both `s` and `t` are constrained to
 * being parameterizations of `g`.
 */
pragma[nomagic]
private predicate typeArgumentsContain(
  GenericType g, ParameterizedType s, ParameterizedType t, int n
) {
  contains01(g, s, t) and n = 1
  or
  contains(g, s, t, n) and
  typeArgumentsContain(g, s, t, n - 1)
}

private predicate typeArgumentsContain0(
  GenericType g, ParameterizedType sParm, ParameterizedType tParm
) {
  exists(RefType s, RefType t |
    containsAux0(g, tParm, s, t) and
    s = parameterisationTypeArgument(g, sParm, 0) and
    s != t
  )
}

/**
 * Holds if the `n`-th type argument of `sParm` contain the `n`-th type
 * argument of `tParm` for both `n = 0` and `n = 1`, where both `sParm` and
 * `tParm` are parameterizations of the same generic type `g`.
 *
 * This is equivalent to
 * ```
 * contains(g, sParm, tParm, 0) and
 * contains(g, sParm, tParm, 1)
 * ```
 * except `contains` is restricted to only include `n >= 2`.
 */
private predicate contains01(GenericType g, ParameterizedType sParm, ParameterizedType tParm) {
  exists(RefType s0, RefType t0, RefType s1, RefType t1 |
    contains01Aux0(g, tParm, s0, t0, t1) and
    contains01Aux1(g, sParm, s0, s1, t1)
  )
}

pragma[nomagic]
private predicate contains01Aux0(
  GenericType g, ParameterizedType tParm, RefType s0, RefType t0, RefType t1
) {
  typeArgumentContains(g, s0, t0, 0) and
  t0 = parameterisationTypeArgument(g, tParm, 0) and
  t1 = parameterisationTypeArgument(g, tParm, 1)
}

pragma[nomagic]
private predicate contains01Aux1(
  GenericType g, ParameterizedType sParm, RefType s0, RefType s1, RefType t1
) {
  typeArgumentContains(g, s1, t1, 1) and
  s0 = parameterisationTypeArgumentVarianceCand(g, sParm, 0) and
  s1 = parameterisationTypeArgumentVarianceCand(g, sParm, 1)
}

pragma[nomagic]
private predicate containsAux0(GenericType g, ParameterizedType tParm, RefType s, RefType t) {
  typeArgumentContains(g, s, t, 0) and
  t = parameterisationTypeArgument(g, tParm, 0) and
  g.getNumberOfTypeParameters() = 1
}

/**
 * Holds if the `n`-th type argument of `sParm` contain the `n`-th type
 * argument of `tParm`, where both `sParm` and `tParm` are parameterizations of
 * the same generic type `g`. The index `n` is restricted to `n >= 2`, the
 * cases `n < 2` are handled by `contains01`.
 *
 * See JLS 4.5.1, Type Arguments of Parameterized Types.
 */
private predicate contains(GenericType g, ParameterizedType sParm, ParameterizedType tParm, int n) {
  exists(RefType s, RefType t |
    containsAux(g, tParm, n, s, t) and
    s = parameterisationTypeArgumentVarianceCand(g, sParm, n)
  )
}

pragma[nomagic]
private predicate containsAux(GenericType g, ParameterizedType tParm, int n, RefType s, RefType t) {
  typeArgumentContains(g, s, t, n) and
  t = parameterisationTypeArgument(g, tParm, n) and
  n >= 2
}

/**
 * Holds if the type argument `s` contains the type argument `t`, where both
 * type arguments occur as index `n` in an instantiation of `g`.
 */
pragma[noinline]
private predicate typeArgumentContains(GenericType g, RefType s, RefType t, int n) {
  typeArgumentContainsAux2(g, s, t, n) and
  s = parameterisationTypeArgumentVarianceCand(g, _, n)
}

pragma[nomagic]
private predicate typeArgumentContainsAux2(GenericType g, RefType s, RefType t, int n) {
  typeArgumentContainsAux1(s, t, n) and
  t = parameterisationTypeArgument(g, _, n)
}

/**
 * Holds if the type argument `s` contains the type argument `t`, where both
 * type arguments occur as index `n` in some parameterized types.
 *
 * See JLS 4.5.1, Type Arguments of Parameterized Types.
 */
private predicate typeArgumentContainsAux1(RefType s, RefType t, int n) {
  exists(int i |
    s = parameterisationTypeArgumentVarianceCand(_, _, i) and
    t = parameterisationTypeArgument(_, _, n) and
    i <= n and
    n <= i
  |
    exists(RefType tUpperBound | tUpperBound = t.(Wildcard).getUpperBound().getType() |
      // ? extends T <= ? extends S if T <: S
      hasSubtypeStar(s.(Wildcard).getUpperBound().getType(), tUpperBound)
      or
      // ? extends T <= ?
      s.(Wildcard).isUnconstrained()
    )
    or
    exists(RefType tLowerBound | tLowerBound = t.(Wildcard).getLowerBound().getType() |
      // ? super T <= ? super S if s <: T
      hasSubtypeStar(tLowerBound, s.(Wildcard).getLowerBound().getType())
      or
      // ? super T <= ?
      s.(Wildcard).isUnconstrained()
      or
      // ? super T <= ? extends Object
      wildcardExtendsObject(s)
    )
    or
    // T <= T
    s = t
    or
    // T <= ? extends T
    hasSubtypeStar(s.(Wildcard).getUpperBound().getType(), t)
    or
    // T <= ? super T
    hasSubtypeStar(t, s.(Wildcard).getLowerBound().getType())
  )
}

pragma[noinline]
private predicate wildcardExtendsObject(Wildcard wc) {
  wc.getUpperBound().getType() instanceof TypeObject
}

private predicate hasSubtypeStar(RefType t, RefType sub) {
  sub = t
  or
  hasSubtype(t, sub)
  or
  exists(RefType mid | hasSubtypeStar(t, mid) and hasSubtype(mid, sub))
}

/** Holds if type `t` declares member `m`. */
predicate declaresMember(Type t, @member m) {
  methods(m, _, _, _, t, _)
  or
  constrs(m, _, _, _, t, _)
  or
  fields(m, _, _, t, _)
  or
  enclInReftype(m, t) and
  // Since the type `@member` in the dbscheme includes all `@reftype`s,
  // anonymous and local classes need to be excluded here.
  not m instanceof AnonymousClass and
  not m instanceof LocalClass
}

/**
 * A common abstraction for all Java types, including
 * primitive, class, interface and array types.
 */
class Type extends Element, @type {
  /**
   * Gets the JVM descriptor for this type, as used in bytecode.
   */
  string getTypeDescriptor() { none() }

  /** Gets the erasure of this type. */
  Type getErasure() { result = erase(this) }
}

/**
 * An array type.
 *
 * Array types are implicitly declared when used; there is
 * an array declaration for each array type used in the system.
 */
class Array extends RefType, @array {
  /**
   * Gets the type of the components of this array type.
   *
   * For example, the component type of `Object[][]` is `Object[]`.
   */
  Type getComponentType() { arrays(this, _, _, _, result) }

  /**
   * Gets the type of the elements used to construct this array type.
   *
   * For example, the element type of `Object[][]` is `Object`.
   */
  Type getElementType() { arrays(this, _, result, _, _) }

  /**
   * Gets the arity of this array type.
   *
   * For example, the dimension of `Object[][]` is 2.
   */
  int getDimension() { arrays(this, _, _, result, _) }

  /**
   * Gets the JVM descriptor for this type, as used in bytecode.
   */
  override string getTypeDescriptor() { result = "[" + this.getComponentType().getTypeDescriptor() }

  override string getAPrimaryQlClass() { result = "Array" }
}

/**
 * A common super-class for various kinds of reference types,
 * including classes, interfaces, type parameters and arrays.
 */
class RefType extends Type, Annotatable, Modifiable, @reftype {
  /** Gets the package in which this type is declared. */
  Package getPackage() {
    classes(this, _, result, _) or
    interfaces(this, _, result, _)
  }

  /** Gets the type in which this reference type is enclosed, if any. */
  RefType getEnclosingType() { enclInReftype(this, result) }

  /** Gets the compilation unit in which this type is declared. */
  override CompilationUnit getCompilationUnit() { result = this.getFile() }

  /** Holds if `t` is an immediate supertype of this type. */
  predicate hasSupertype(RefType t) { hasSubtype(t, this) }

  /** Holds if `t` is an immediate subtype of this type. */
  predicate hasSubtype(RefType t) { hasSubtype(this, t) }

  /** Gets a direct subtype of this type. */
  RefType getASubtype() { hasSubtype(this, result) }

  /** Gets a direct supertype of this type. */
  RefType getASupertype() { hasSubtype(result, this) }

  /** Gets a direct or indirect supertype of this type, including itself. */
  RefType getAnAncestor() { hasSubtype*(result, this) }

  /**
   * Gets the source declaration of a direct supertype of this type, excluding itself.
   *
   * Note, that a generic type is the source declaration of a direct supertype
   * of itself, namely the corresponding raw type, and this case is thus
   * explicitly excluded. See also `getSourceDeclaration()`.
   */
  pragma[noinline]
  RefType getASourceSupertype() {
    result = this.getASupertype().getSourceDeclaration() and
    result != this
  }

  /**
   * Holds if `t` is an immediate super-type of this type using only the immediate
   * `extends` or `implements` relationships.  In particular, this excludes
   * parameter containment sub-typing for parameterized types.
   */
  predicate extendsOrImplements(RefType t) {
    extendsReftype(this, t) or
    implInterface(this, t) or
    typeVarSubtypeBound(t, this)
  }

  /** Holds if this type declares any members. */
  predicate hasMember() { exists(getAMember()) }

  /** Gets a member declared in this type. */
  Member getAMember() { this = result.getDeclaringType() }

  /** Gets a method declared in this type. */
  Method getAMethod() { this = result.getDeclaringType() }

  /** Gets a constructor declared in this type. */
  Constructor getAConstructor() { this = result.getDeclaringType() }

  /** Gets a method or constructor declared in this type. */
  Callable getACallable() { this = result.getDeclaringType() }

  /** Gets a field declared in this type. */
  Field getAField() { this = result.getDeclaringType() }

  /** Holds if this type declares a method with the specified name. */
  predicate declaresMethod(string name) { this.getAMethod().getName() = name }

  /** Holds if this type declares a method with the specified name and number of parameters. */
  predicate declaresMethod(string name, int n) {
    exists(Method m | m = this.getAMethod() |
      m.getName() = name and
      m.getNumberOfParameters() = n
    )
  }

  /** Holds if this type declares a field with the specified name. */
  predicate declaresField(string name) { this.getAField().getName() = name }

  /** Gets the number of methods declared in this type. */
  int getNumberOfMethods() { result = count(Method m | m.getDeclaringType() = this) }

  /**
   * Holds if this type declares or inherits method `m`, which is declared
   * in `declaringType`.
   */
  predicate hasMethod(Method m, RefType declaringType) { this.hasMethod(m, declaringType, false) }

  /**
   * Holds if this type declares or inherits method `m`, which is declared
   * in `declaringType`. Methods that would be inherited if they were public,
   * but are not inherited due to being package protected, are also included
   * and indicated by `hidden` being true.
   */
  cached
  predicate hasMethod(Method m, RefType declaringType, boolean hidden) {
    this.hasNonInterfaceMethod(m, declaringType, hidden)
    or
    this.hasInterfaceMethod(m, declaringType) and hidden = false
  }

  private predicate hasNonInterfaceMethod(Method m, RefType declaringType, boolean hidden) {
    m = this.getAMethod() and
    this = declaringType and
    not declaringType instanceof Interface and
    hidden = false
    or
    exists(RefType sup, boolean h1, boolean h2 |
      (
        if m.isPackageProtected() and sup.getPackage() != this.getPackage()
        then h1 = true
        else h1 = false
      ) and
      (not sup instanceof Interface or this instanceof Interface) and
      this.extendsOrImplements(sup) and
      sup.hasNonInterfaceMethod(m, declaringType, h2) and
      hidden = h1.booleanOr(h2) and
      exists(string signature |
        methods(m, _, signature, _, _, _) and not methods(_, _, signature, _, this, _)
      ) and
      m.isInheritable()
    )
  }

  private predicate cannotInheritInterfaceMethod(string signature) {
    methods(_, _, signature, _, this, _)
    or
    exists(Method m | this.hasNonInterfaceMethod(m, _, false) and methods(m, _, signature, _, _, _))
  }

  private predicate interfaceMethodCandidateWithSignature(
    Method m, string signature, RefType declaringType
  ) {
    m = this.getAMethod() and
    this = declaringType and
    declaringType instanceof Interface and
    methods(m, _, signature, _, _, _)
    or
    exists(RefType sup |
      sup.interfaceMethodCandidateWithSignature(m, signature, declaringType) and
      not this.cannotInheritInterfaceMethod(signature) and
      this.extendsOrImplements(sup) and
      m.isInheritable()
    )
  }

  pragma[nomagic]
  private predicate overrideEquivalentInterfaceMethodCandidates(Method m1, Method m2) {
    exists(string signature |
      this.interfaceMethodCandidateWithSignature(m1, signature, _) and
      this.interfaceMethodCandidateWithSignature(m2, signature, _) and
      m1 != m2 and
      m2.overrides(_) and
      any(Method m).overrides(m1)
    )
  }

  pragma[noinline]
  private predicate overriddenInterfaceMethodCandidate(Method m) {
    exists(Method m2 |
      this.overrideEquivalentInterfaceMethodCandidates(m, m2) and
      m2.overrides(m)
    )
  }

  private predicate hasInterfaceMethod(Method m, RefType declaringType) {
    this.interfaceMethodCandidateWithSignature(m, _, declaringType) and
    not this.overriddenInterfaceMethodCandidate(m)
  }

  /** Holds if this type declares or inherits the specified member. */
  predicate inherits(Member m) {
    exists(Field f | f = m |
      f = this.getAField()
      or
      not f.isPrivate() and not this.declaresField(f.getName()) and this.getASupertype().inherits(f)
      or
      this.getSourceDeclaration().inherits(f)
    )
    or
    this.hasMethod(m.(Method), _)
  }

  /** Holds if this is a top-level type, which is not nested inside any other types. */
  predicate isTopLevel() { this instanceof TopLevelType }

  /** Holds if this type is declared in a specified package with the specified name. */
  predicate hasQualifiedName(string package, string type) {
    this.getPackage().hasName(package) and type = this.nestedName()
  }

  /**
   * Gets the JVM descriptor for this type, as used in bytecode.
   */
  override string getTypeDescriptor() {
    result =
      "L" + this.getPackage().getName().replaceAll(".", "/") + "/" +
        this.getSourceDeclaration().nestedName() + ";"
  }

  /**
   * Gets the qualified name of this type.
   */
  string getQualifiedName() {
    exists(string pkgName | pkgName = getPackage().getName() |
      if pkgName = "" then result = nestedName() else result = pkgName + "." + nestedName()
    )
  }

  /** Gets the nested name of this type. */
  string nestedName() {
    not this instanceof NestedType and result = this.getName()
    or
    this.(NestedType).getEnclosingType().nestedName() + "$" + this.getName() = result
  }

  /**
   * Gets the source declaration of this type.
   *
   * For parameterized instances of generic types and raw types, the
   * source declaration is the corresponding generic type.
   *
   * For non-parameterized types declared inside a parameterized
   * instance of a generic type, the source declaration is the
   * corresponding type in the generic type.
   *
   * For all other types, the source declaration is the type itself.
   */
  RefType getSourceDeclaration() { result = this }

  /** Holds if this type is the same as its source declaration. */
  predicate isSourceDeclaration() { this.getSourceDeclaration() = this }

  /** Cast this reference type to a class that provides access to metrics information. */
  MetricRefType getMetrics() { result = this }

  /**
   * A common (reflexive, transitive) subtype of the erasures of
   * types `t1` and `t2`, if it exists.
   *
   * If there is no such common subtype, then the two types are disjoint.
   * However, the converse is not true; for example, the parameterized types
   * `List<Integer>` and `Collection<String>` are disjoint,
   * but their erasures (`List` and `Collection`, respectively)
   * do have common subtypes (such as `List` itself).
   *
   * For the definition of the notion of *erasure* see JLS v8, section 4.6 (Type Erasure).
   */
  pragma[inline]
  RefType commonSubtype(RefType other) {
    result.getASourceSupertype*() = erase(this) and
    result.getASourceSupertype*() = erase(other)
  }
}

/** A type that is the same as its source declaration. */
class SrcRefType extends RefType {
  SrcRefType() { this.isSourceDeclaration() }
}

/** A class declaration. */
class Class extends RefType, @class {
  /** Holds if this class is an anonymous class. */
  predicate isAnonymous() { isAnonymClass(this, _) }

  /** Holds if this class is a local class. */
  predicate isLocal() { isLocalClass(this, _) }

  /** Holds if this class is package protected, that is, neither public nor private nor protected. */
  predicate isPackageProtected() {
    not isPrivate() and
    not isProtected() and
    not isPublic()
  }

  override RefType getSourceDeclaration() { classes(this, _, _, result) }

  /**
   * Gets an annotation that applies to this class.
   *
   * Note that a class may inherit annotations from super-classes.
   */
  override Annotation getAnAnnotation() {
    result = RefType.super.getAnAnnotation()
    or
    exists(AnnotationType tp | tp = result.getType() |
      tp.isInherited() and
      not exists(Annotation ann | ann = RefType.super.getAnAnnotation() | ann.getType() = tp) and
      result = this.getASupertype().(Class).getAnAnnotation()
    )
  }

  override string getAPrimaryQlClass() { result = "Class" }
}

/**
 * PREVIEW FEATURE in Java 14. Subject to removal in a future release.
 *
 * A record declaration.
 */
class Record extends Class {
  Record() { isRecord(this) }
}

/** An intersection type. */
class IntersectionType extends RefType, @class {
  IntersectionType() {
    exists(string shortname |
      classes(this, shortname, _, _) and
      shortname.matches("% & ...")
    )
  }

  private RefType superType() { extendsReftype(this, result) }

  private RefType superInterface() { implInterface(this, result) }

  /** Gets a textual representation of this type that includes all the intersected types. */
  string getLongName() {
    result = superType().toString() + concat(" & " + superInterface().toString())
  }

  /** Gets the first bound of this intersection type. */
  RefType getFirstBound() { extendsReftype(this, result) }
}

/** An anonymous class. */
class AnonymousClass extends NestedClass {
  AnonymousClass() { this.isAnonymous() }

  /**
   * Utility method: an integer that is larger for classes that
   * are defined textually later.
   */
  private int rankInParent(RefType parent) {
    this.getEnclosingType() = parent and
    exists(Location myLocation, File f, int maxCol | myLocation = this.getLocation() |
      f = myLocation.getFile() and
      maxCol = max(Location loc | loc.getFile() = f | loc.getStartColumn()) and
      result = myLocation.getStartLine() * maxCol + myLocation.getStartColumn()
    )
  }

  /**
   * Gets the JVM descriptor for this type, as used in bytecode.
   *
   * For an anonymous class, the type descriptor is the descriptor of the
   * enclosing type followed by a (1-based) counter of anonymous classes
   * declared within that type.
   */
  override string getTypeDescriptor() {
    exists(RefType parent | parent = this.getEnclosingType() |
      exists(int num |
        num = 1 + count(AnonymousClass other | other.rankInParent(parent) < rankInParent(parent))
      |
        exists(string parentWithSemi | parentWithSemi = parent.getTypeDescriptor() |
          result = parentWithSemi.prefix(parentWithSemi.length() - 1) + "$" + num + ";"
        )
      )
    )
  }

  /** Gets the class instance expression where this anonymous class occurs. */
  ClassInstanceExpr getClassInstanceExpr() { isAnonymClass(this, result) }

  override string toString() {
    result = "new " + this.getClassInstanceExpr().getTypeName() + "(...) { ... }"
  }

  /**
   * Gets the qualified name of this type.
   *
   * Anonymous classes do not have qualified names, so we use
   * the string `"<anonymous class>"` as a placeholder.
   */
  override string getQualifiedName() { result = "<anonymous class>" }

  override string getAPrimaryQlClass() { result = "AnonymousClass" }
}

/** A local class. */
class LocalClass extends NestedClass {
  LocalClass() { this.isLocal() }

  /** Gets the statement that declares this local class. */
  LocalClassDeclStmt getLocalClassDeclStmt() { isLocalClass(this, result) }

  override string getAPrimaryQlClass() { result = "LocalClass" }
}

/** A top-level type. */
class TopLevelType extends RefType {
  TopLevelType() {
    not enclInReftype(this, _) and
    (this instanceof Class or this instanceof Interface)
  }
}

/** A top-level class. */
class TopLevelClass extends TopLevelType, Class { }

/** A nested type is a type declared within another type. */
class NestedType extends RefType {
  NestedType() { enclInReftype(this, _) }

  /** Gets the type enclosing this nested type. */
  override RefType getEnclosingType() { enclInReftype(this, result) }

  /** Gets the nesting depth of this nested type. Top-level types have nesting depth 0. */
  int getNestingDepth() {
    if getEnclosingType() instanceof NestedType
    then result = getEnclosingType().(NestedType).getNestingDepth() + 1
    else result = 1
  }

  override predicate isPublic() {
    super.isPublic()
    or
    // JLS 9.5: A member type declaration in an interface is implicitly public and static
    exists(Interface i | this = i.getAMember())
  }

  override predicate isStrictfp() {
    super.isStrictfp()
    or
    // JLS 8.1.1.3, JLS 9.1.1.2
    getEnclosingType().isStrictfp()
  }

  /**
   * Holds if this nested type is static.
   *
   * A nested type is static either if it is explicitly declared as such
   * using the modifier `static`, or if it is implicitly static
   * because one of the following holds:
   *
   * - it is a member type of an interface,
   * - it is a member interface, or
   * - it is a nested enum type.
   *
   * See JLS v8, section 8.5.1 (Static Member Type Declarations),
   * section 8.9 (Enums) and section 9.5 (Member Type Declarations).
   */
  override predicate isStatic() {
    super.isStatic()
    or
    // JLS 8.5.1: A member interface is implicitly static.
    this instanceof Interface
    or
    // JLS 8.9: A nested enum type is implicitly static.
    this instanceof EnumType
    or
    // JLS 9.5: A member type declaration in an interface is implicitly public and static
    exists(Interface i | this = i.getAMember())
  }
}

/**
 * A class declared within another type.
 *
 * This includes (static and non-static) member classes,
 * local classes and anonymous classes.
 */
class NestedClass extends NestedType, Class { }

/**
 * An inner class is a nested class that is neither
 * explicitly nor implicitly declared static.
 */
class InnerClass extends NestedClass {
  InnerClass() { not this.isStatic() }

  /**
   * Holds if an instance of this inner class holds a reference to its
   * enclosing class.
   */
  predicate hasEnclosingInstance() {
    // JLS 15.9.2. Determining Enclosing Instances
    not this.(AnonymousClass).getClassInstanceExpr().isInStaticContext() and
    not this.(LocalClass).getLocalClassDeclStmt().getEnclosingCallable().isStatic()
  }
}

/** An interface. */
class Interface extends RefType, @interface {
  override RefType getSourceDeclaration() { interfaces(this, _, _, result) }

  override predicate isAbstract() {
    // JLS 9.1.1.1: "Every interface is implicitly abstract"
    any()
  }

  /** Holds if this interface is package protected, that is, neither public nor private nor protected. */
  predicate isPackageProtected() {
    not isPrivate() and
    not isProtected() and
    not isPublic()
  }

  override string getAPrimaryQlClass() { result = "Interface" }
}

/** A class or interface. */
class ClassOrInterface extends RefType {
  ClassOrInterface() {
    this instanceof Class or
    this instanceof Interface
  }
}

/**
 * A primitive type.
 *
 * This includes `boolean`, `byte`, `short`,
 * `char`, `int`, `long`, `float`,
 * and `double`.
 */
class PrimitiveType extends Type, @primitive {
  PrimitiveType() { this.getName().regexpMatch("float|double|int|boolean|short|byte|char|long") }

  /** Gets the boxed type corresponding to this primitive type. */
  BoxedType getBoxedType() { result.getPrimitiveType() = this }

  /**
   * Gets the JVM descriptor for this type, as used in bytecode.
   */
  override string getTypeDescriptor() {
    this.hasName("float") and result = "F"
    or
    this.hasName("double") and result = "D"
    or
    this.hasName("int") and result = "I"
    or
    this.hasName("boolean") and result = "Z"
    or
    this.hasName("short") and result = "S"
    or
    this.hasName("byte") and result = "B"
    or
    this.hasName("char") and result = "C"
    or
    this.hasName("long") and result = "J"
  }

  /**
   * Gets a default value for this primitive type, as assigned by the compiler
   * for variables that are declared but not initialized explicitly.
   * Typically zero for numeric and character types and `false` for `boolean`.
   *
   * For numeric primitive types, default literals of one numeric type are also
   * considered to be default values of all other numeric types, even if they
   * require an explicit cast.
   */
  Literal getADefaultValue() {
    getName() = "boolean" and result.getLiteral() = "false"
    or
    getName() = "char" and
    (result.getLiteral() = "'\\0'" or result.getLiteral() = "'\\u0000'")
    or
    getName().regexpMatch("(float|double|int|short|byte|long)") and
    result.getLiteral().regexpMatch("0(\\.0)?+[lLfFdD]?+")
  }

  override string getAPrimaryQlClass() { result = "PrimitiveType" }
}

/** The type of the `null` literal. */
class NullType extends Type, @primitive {
  NullType() { this.hasName("<nulltype>") }

  override string getAPrimaryQlClass() { result = "NullType" }
}

/** The `void` type. */
class VoidType extends Type, @primitive {
  VoidType() { this.hasName("void") }

  /**
   * Gets the JVM descriptor for this type, as used in bytecode.
   */
  override string getTypeDescriptor() { result = "V" }

  override string getAPrimaryQlClass() { result = "VoidType" }
}

/**
 * A boxed type.
 *
 * This includes `Boolean`, `Byte`, `Short`,
 * `Character`, `Integer`, `Long`, `Float`,
 * and `Double`.
 */
class BoxedType extends RefType {
  BoxedType() {
    this.hasQualifiedName("java.lang", "Float") or
    this.hasQualifiedName("java.lang", "Double") or
    this.hasQualifiedName("java.lang", "Integer") or
    this.hasQualifiedName("java.lang", "Boolean") or
    this.hasQualifiedName("java.lang", "Short") or
    this.hasQualifiedName("java.lang", "Byte") or
    this.hasQualifiedName("java.lang", "Character") or
    this.hasQualifiedName("java.lang", "Long")
  }

  /** Gets the primitive type corresponding to this boxed type. */
  PrimitiveType getPrimitiveType() {
    this.hasName("Float") and result.hasName("float")
    or
    this.hasName("Double") and result.hasName("double")
    or
    this.hasName("Integer") and result.hasName("int")
    or
    this.hasName("Boolean") and result.hasName("boolean")
    or
    this.hasName("Short") and result.hasName("short")
    or
    this.hasName("Byte") and result.hasName("byte")
    or
    this.hasName("Character") and result.hasName("char")
    or
    this.hasName("Long") and result.hasName("long")
  }
}

/**
 * An enumerated type.
 *
 * Each enum type has zero or more enum constants which can
 * be enumerated over.
 * The type of an enum constant is the enum type itself.
 *
 * For example,
 *
 * ```
 *   enum X { A, B, C }
 * ```
 * is an enum type declaration, where the type of the enum
 * constant `X.A` is `X`.
 */
class EnumType extends Class {
  EnumType() { isEnumType(this) }

  /** Gets the enum constant with the specified name. */
  EnumConstant getEnumConstant(string name) {
    fields(result, _, _, this, _) and result.hasName(name)
  }

  /** Gets an enum constant declared in this enum type. */
  EnumConstant getAnEnumConstant() { fields(result, _, _, this, _) }

  override predicate isFinal() {
    // JLS 8.9: An enum declaration is implicitly `final` unless it contains
    // at least one enum constant that has a class body.
    not getAnEnumConstant().getAnAssignedValue().getType() instanceof AnonymousClass
  }
}

/** An enum constant is a member of a enum type. */
class EnumConstant extends Field {
  EnumConstant() { isEnumConst(this) }

  // JLS 8.9.3: For each enum constant `c` in the body of the declaration of
  // [enum type] `E`, `E` has an implicitly declared `public static final`
  // field of type `E` that has the same name as `c`.
  override predicate isPublic() { any() }

  override predicate isStatic() { any() }

  override predicate isFinal() { any() }
}

/**
 * Gets the erasure of a type.
 *
 * See JLS v8, section 4.6 (Type Erasure).
 */
cached
private Type erase(Type t) {
  result = t.(Class).getSourceDeclaration() and not t instanceof IntersectionType
  or
  result = erase(t.(IntersectionType).getFirstBound())
  or
  result = t.(Interface).getSourceDeclaration()
  or
  result.(Array).getComponentType() = erase(t.(Array).getComponentType())
  or
  result = erase(t.(BoundedType).getFirstUpperBoundType())
  or
  result = t.(NullType)
  or
  result = t.(VoidType)
  or
  result = t.(PrimitiveType)
}

/**
 * Is there a common (reflexive, transitive) subtype of the erasures of
 * types `t1` and `t2`?
 *
 * If there is no such common subtype, then the two types are disjoint.
 * However, the converse is not true; for example, the parameterized types
 * `List<Integer>` and `Collection<String>` are disjoint,
 * but their erasures (`List` and `Collection`, respectively)
 * do have common subtypes (such as `List` itself).
 *
 * For the definition of the notion of *erasure* see JLS v8, section 4.6 (Type Erasure).
 */
pragma[inline]
predicate haveIntersection(RefType t1, RefType t2) {
  exists(RefType e1, RefType e2 | e1 = erase(t1) and e2 = erase(t2) |
    erasedHaveIntersection(e1, e2)
  )
}

/**
 * Holds if there is a common (reflexive, transitive) subtype of the erased
 * types `t1` and `t2`.
 */
predicate erasedHaveIntersection(RefType t1, RefType t2) {
  exists(SrcRefType commonSub |
    commonSub.getASourceSupertype*() = t1 and commonSub.getASourceSupertype*() = t2
  ) and
  t1 = erase(_) and
  t2 = erase(_)
}

/** An integral type, which may be either a primitive or a boxed type. */
class IntegralType extends Type {
  IntegralType() {
    exists(string name |
      name = this.(PrimitiveType).getName() or name = this.(BoxedType).getPrimitiveType().getName()
    |
      name.regexpMatch("byte|char|short|int|long")
    )
  }
}

/** A boolean type, which may be either a primitive or a boxed type. */
class BooleanType extends Type {
  BooleanType() {
    exists(string name |
      name = this.(PrimitiveType).getName() or name = this.(BoxedType).getPrimitiveType().getName()
    |
      name = "boolean"
    )
  }
}

/** A character type, which may be either a primitive or a boxed type. */
class CharacterType extends Type {
  CharacterType() {
    exists(string name |
      name = this.(PrimitiveType).getName() or name = this.(BoxedType).getPrimitiveType().getName()
    |
      name = "char"
    )
  }
}

/** A numeric or character type, which may be either a primitive or a boxed type. */
class NumericOrCharType extends Type {
  NumericOrCharType() {
    exists(string name |
      name = this.(PrimitiveType).getName() or name = this.(BoxedType).getPrimitiveType().getName()
    |
      name.regexpMatch("byte|char|short|int|long|double|float")
    )
  }
}

/** A floating point type, which may be either a primitive or a boxed type. */
class FloatingPointType extends Type {
  FloatingPointType() {
    exists(string name |
      name = this.(PrimitiveType).getName() or name = this.(BoxedType).getPrimitiveType().getName()
    |
      name.regexpMatch("float|double")
    )
  }
}
