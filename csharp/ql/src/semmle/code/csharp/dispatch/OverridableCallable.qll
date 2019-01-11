/**
 * Provides classes that define callables that can be overridden or
 * implemented.
 */

import csharp

/**
 * A callable that can be overridden or implemented.
 *
 * Unlike the class `Virtualizable`, this class only includes methods that
 * can actually be overriden/implemented. Additionally, this class includes
 * accessors whose declarations can actually be overridden/implemented.
 */
class OverridableCallable extends Callable {
  OverridableCallable() {
    this.(Method).isOverridableOrImplementable() or
    this.(Accessor).getDeclaration().isOverridableOrImplementable()
  }

  /** Gets a callable that immediately overrides this callable, if any. */
  Callable getAnOverrider() { none() }

  /**
   * Gets a callable that immediately implements this interface callable,
   * if any.
   */
  Callable getAnImplementor(ValueOrRefType t) { none() }

  /**
   * Gets a callable that immediately implements this interface member,
   * if any.
   *
   * The type `t` is a (transitive, reflexive) sub type of a type that
   * implements the interface type in which this callable is declared,
   * in such a way that the result is the implementation of this
   * callable.
   *
   * Example:
   *
   * ```
   * interface I { void M(); }
   *
   * class A { public void M() { } }
   *
   * class B : A, I { }
   *
   * class C : A, I { new public void M() }
   *
   * class D : C
   *
   * class E : A
   * ```
   *
   * In the example above, the following (and nothing else) holds:
   * `I.M.getAnImplementorSubType(B) = A.M`,
   * `I.M.getAnImplementorSubType(C) = C.M`, and
   * `I.M.getAnImplementorSubType(D) = C.M`.
   */
  private Callable getAnImplementorSubType(ValueOrRefType t) {
    result = getAnImplementor(t)
    or
    exists(ValueOrRefType mid |
      result = getAnImplementorSubType(mid) and
      t.getBaseClass() = mid and
      // There must be no other implementation of this callable in `t`
      forall(Callable other | other = getAnImplementor(t) | other = result)
    )
  }

  /**
   * Gets a callable that (transitively) implements this interface callable,
   * if any. That is, either this interface callable is immediately implemented
   * by the result, or the result overrides (transitively) another callable that
   * immediately implements this interface callable.
   *
   * Note that this is generally *not* equivalent with
   *
   * ```
   * result = getAnImplementor()
   * or
   * result = getAnImplementor().(OverridableCallable).getAnOverrider+()`
   * ```
   *
   * as the example below illustrates:
   *
   * ```
   * interface I { void M(); }
   *
   * class A { public virtual void M() { } }
   *
   * class B : A, I { }
   *
   * class C : A { public override void M() }
   *
   * class D : B { public override void M() }
   * ```
   *
   * If this callable is `I.M` then `A.M = getAnUltimateImplementor() ` and
   * `D.M = getAnUltimateImplementor()`. However, it is *not* the case that
   * `C.M = getAnUltimateImplementor()`, because `C` is not a sub type of `I`.
   */
  Callable getAnUltimateImplementor() { none() }

  /**
   * Gets a callable that overrides (transitively) another callable that
   * implements this interface callable, if any.
   */
  private Callable getAnOverridingImplementor() {
    result = getAnUltimateImplementor() and
    not result = getAnImplementor(_)
  }

  /**
   * Gets the unique callable inherited by (or defined in) type `t` that
   * overrides, implements, or equals this callable, where this callable
   * is defined in a (transitive, reflexive) base type of `t`.
   *
   * Example:
   *
   * ```
   * class C1 { public virtual void M() { } }
   *
   * class C2 : C1 { public override void M() { } }
   *
   * class C3 : C2 { }
   * ```
   *
   * The following holds:
   *
   * - `C1.M = C1.M.getInherited(C1)`,
   * - `C2.M = C1.M.getInherited(C2)`,
   * - `C2.M = C1.M.getInherited(C3)`,
   * - `C2.M = C2.M.getInherited(C2)`, and
   * - `C2.M = C2.M.getInherited(C3)`.
   */
  Callable getInherited(SourceDeclarationType t) {
    exists(Callable sourceDecl | result = getInherited1(t, sourceDecl) |
      hasSourceDeclarationCallable(t, sourceDecl)
    )
  }

  private Callable getInherited0(SourceDeclarationType t) {
    // A (transitive, reflexive) overrider
    t = this.hasOverrider(result).getASubType*().getSourceDeclaration()
    or
    // An interface implementation
    exists(ValueOrRefType s |
      result = getAnImplementorSubType(s) and
      t = s.getSourceDeclaration()
    )
    or
    // A (transitive) overrider of an interface implementation
    t = this.hasOverridingImplementor(result).getASubType*().getSourceDeclaration()
  }

  private Callable getInherited1(SourceDeclarationType t, Callable sourceDecl) {
    result = this.getInherited0(t) and
    sourceDecl = result.getSourceDeclaration()
  }

  pragma[noinline]
  private ValueOrRefType hasOverrider(Callable c) {
    c = this.getAnOverrider*() and
    result = c.getDeclaringType()
  }

  pragma[noinline]
  private ValueOrRefType hasOverridingImplementor(Callable c) {
    c = this.getAnOverridingImplementor() and
    result = c.getDeclaringType()
  }

  /**
   * Gets a callable defined in a sub type of `t` that overrides/implements
   * this callable, if any.
   *
   * The type `t` may be a constructed type: For example, if `t = C<int>`,
   * then only callables defined in sub types of `C<int>` (and e.g. not
   * `C<string>`) are valid. In particular, if `C2<T> : C<T>` and `C2`
   * contains a callable that overrides this callable, then only if `C2<int>`
   * is ever constructed will the callable in `C2` be considered valid.
   */
  Callable getAnOverrider(TypeWithoutTypeParameters t) {
    exists(OverridableCallable oc, ValueOrRefType sub |
      result = oc.getAnOverriderAux(sub) and
      t = oc.getAnOverriderBaseType(sub) and
      oc = getABoundInstance()
    )
  }

  // predicate folding to get proper join order
  private Callable getAnOverriderAux(ValueOrRefType t) {
    not declaredInTypeWithTypeParameters() and
    (
      // A (transitive) overrider
      result = getAnOverrider+() and
      t = result.getDeclaringType()
      or
      // An interface implementation
      result = getAnImplementorSubType(t)
      or
      // A (transitive) overrider of an interface implementation
      result = getAnOverridingImplementor() and
      t = result.getDeclaringType()
    )
  }

  private TypeWithoutTypeParameters getAnOverriderBaseType(ValueOrRefType t) {
    exists(getAnOverriderAux(t)) and
    exists(Type t0 | t0 = t.getABaseType*() |
      result = t0
      or
      result = t0.(ConstructedType).getUnboundGeneric()
    )
  }

  /**
   * Gets a bound instance of this callable.
   *
   * If this callable is defined in a type that contains type parameters,
   * returns an instance defined in a constructed type, otherwise the
   * callable itself.
   */
  private OverridableCallable getABoundInstance() {
    not declaredInTypeWithTypeParameters() and
    result = this
    or
    result.getSourceDeclaration() = getSourceDeclarationInTypeWithTypeParameters()
  }

  // predicate folding to get proper join order
  private OverridableCallable getSourceDeclarationInTypeWithTypeParameters() {
    declaredInTypeWithTypeParameters() and
    result = getSourceDeclaration()
  }

  private predicate declaredInTypeWithTypeParameters() {
    exists(ValueOrRefType t | t = getDeclaringType() |
      t.containsTypeParameters()
      or
      // Access to a local callable, `this.M()`, in a generic class
      // results in a static target where the declaring type is
      // the unbound generic version
      t instanceof UnboundGenericType
    )
  }
}

pragma[noinline]
private predicate hasSourceDeclarationCallable(ValueOrRefType t, Callable sourceDecl) {
  exists(Callable c | t.hasCallable(c) | sourceDecl = c.getSourceDeclaration())
}

/** An overridable method. */
class OverridableMethod extends Method, OverridableCallable {
  override Method getAnOverrider() { result = Method.super.getAnOverrider() }

  override Method getAnImplementor(ValueOrRefType t) { result = Method.super.getAnImplementor(t) }

  override Method getAnUltimateImplementor() { result = Method.super.getAnUltimateImplementor() }

  override Method getInherited(SourceDeclarationType t) {
    result = OverridableCallable.super.getInherited(t)
  }

  override Method getAnOverrider(TypeWithoutTypeParameters t) {
    result = OverridableCallable.super.getAnOverrider(t)
  }
}

/** An overridable accessor. */
class OverridableAccessor extends Accessor, OverridableCallable {
  override Accessor getAnOverrider() { overrides(result, this) }

  override Accessor getAnImplementor(ValueOrRefType t) {
    exists(Virtualizable implementor, int kind |
      getAnImplementorAux(t, implementor, kind) and
      result.getDeclaration() = implementor and
      getAccessorKind(result) = kind
    )
  }

  // predicate folding to get proper join order
  private predicate getAnImplementorAux(ValueOrRefType t, Virtualizable implementor, int kind) {
    exists(Virtualizable implementee |
      implementee = getDeclaration() and
      kind = getAccessorKind(this) and
      implementor = implementee.getAnImplementor(t)
    )
  }

  override Accessor getAnUltimateImplementor() {
    exists(Virtualizable implementor, int kind |
      getAnUltimateImplementorAux(implementor, kind) and
      result.getDeclaration() = implementor and
      getAccessorKind(result) = kind
    )
  }

  // predicate folding to get proper join order
  private predicate getAnUltimateImplementorAux(Virtualizable implementor, int kind) {
    exists(Virtualizable implementee |
      implementee = getDeclaration() and
      kind = getAccessorKind(this) and
      implementor = implementee.getAnUltimateImplementor()
    )
  }

  override Accessor getInherited(SourceDeclarationType t) {
    result = OverridableCallable.super.getInherited(t)
  }

  override Accessor getAnOverrider(TypeWithoutTypeParameters t) {
    result = OverridableCallable.super.getAnOverrider(t)
  }
}

private int getAccessorKind(Accessor a) {
  accessors(a, result, _, _, _) or
  event_accessors(a, -result, _, _, _)
}

/** A type not containing type parameters. */
class TypeWithoutTypeParameters extends Type {
  TypeWithoutTypeParameters() { not containsTypeParameters() }
}

/** A source declared type. */
class SourceDeclarationType extends TypeWithoutTypeParameters {
  SourceDeclarationType() { this = getSourceDeclaration() }
}
