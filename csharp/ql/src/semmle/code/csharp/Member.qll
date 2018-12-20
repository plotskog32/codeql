/** Provides classes relating to declarations and type members. */

import Element
import Variable
import Callable
import Modifier
private import Implements
private import dotnet

/**
 * A declaration.
 *
 * Either a modifiable (`Modifiable`) or an assignable (`Assignable`).
 */
class Declaration extends DotNet::Declaration, Element, @declaration {
  override ValueOrRefType getDeclaringType() { none() }

  /** Holds if this declaration is unconstructed and in source code. */
  predicate isSourceDeclaration() { fromSource() and this=getSourceDeclaration() }

  override string toString() { result = this.getName() }

  /**
   * Gets the fully qualified name of this declaration, including types, for example
   * the fully qualified name with types of `M` on line 3 is `N.C.M(int, string)` in
   *
   * ```
   * namespace N {
   *   class C {
   *     void M(int i, string s) { }
   *   }
   * }
   * ```
   */
  string getQualifiedNameWithTypes() {
    result = this.getDeclaringType().getQualifiedName() + "." + this.toStringWithTypes()
  }

  /**
   * Holds if this declaration has been generated by the compiler, for example
   * implicit constructors or accessors.
   */
  predicate isCompilerGenerated() {
    compiler_generated(this)
  }
}

/** A declaration that can have a modifier. */
class Modifiable extends Declaration, @modifiable {
  /** Gets a modifier of this declaration. */
  Modifier getAModifier() { has_modifiers(this, result) }

  /** Holds if this declaration has `name` as a modifier. */
  predicate hasModifier(string name) { this.getAModifier().hasName(name) }

  /** Holds if this declaration is `static`. */
  predicate isStatic() { this.hasModifier("static") }

  /** Holds if this declaration is `public`. */
  predicate isPublic() { this.hasModifier("public") }

  /** Holds if this declaration is `protected`. */
  predicate isProtected() { this.hasModifier("protected") }

  /** Holds if this declaration is `internal`. */
  predicate isInternal() { this.hasModifier("internal") }

  /** Holds if this declaration is `private`. */
  predicate isPrivate() { this.hasModifier("private") }

  /** Holds if this declaration has the modifier `new`. */
  predicate isNew() { this.hasModifier("new") }

  /** Holds if this declaration is `sealed`. */
  predicate isSealed() { this.hasModifier("sealed") }

  /** Holds if this declaration is `abstract`. */
  predicate isAbstract() { this.hasModifier("abstract") }

  /** Holds if this declaration is `extern`. */
  predicate isExtern() { this.hasModifier("extern") }

  /** Holds if this declaration is `partial`. */
  predicate isPartial() { this.hasModifier("partial") }

  /** Holds if this declaration is `const`. */
  predicate isConst() { this.hasModifier("const") }

  /** Holds if this declaration is `unsafe`. */
  predicate isUnsafe() { this.hasModifier("unsafe") }

  /** Holds if this declaration is `async`. */
  predicate isAsync() { this.hasModifier("async") }

  /**
   * Holds if this declaration is effectively `private` (either directly or
   * because one of the enclosing types is `private`).
   */
  predicate isEffectivelyPrivate() {
    this.isPrivate() or
    this.getDeclaringType+().isPrivate()
  }

  /**
   * Holds if this declaration is effectively `internal` (either directly or
   * because one of the enclosing types is `internal`).
   */
  predicate isEffectivelyInternal() {
    this.isInternal() or
    this.getDeclaringType+().isInternal()
  }
}

/** A declaration that is a member of a type. */
class Member extends DotNet::Member, Modifiable, @member {
  /** Gets an access to this member. */
  MemberAccess getAnAccess() { result.getTarget() = this }
}

/**
 * A member where the `virtual` modifier is valid. That is, a method,
 * a property, an indexer, or an event.
 *
 * Equivalently, these are the members that can be defined in an interface.
 */
class Virtualizable extends Member, @virtualizable {
  /** Holds if this member has the modifier `override`. */
  predicate isOverride() { this.hasModifier("override") }

  /** Holds if this member is `virtual`. */
  predicate isVirtual() { this.hasModifier("virtual") }

  override predicate isPublic() {
    Member.super.isPublic() or
    implementsExplicitInterface()
  }

  /**
   * Gets any interface this member explicitly implements; this only applies
   * to members that can be declared on an interface, i.e. methods, properties,
   * indexers and events.
   */
  Interface getExplicitlyImplementedInterface() {
    explicitly_implements(this, getTypeRef(result))
  }

  /**
   * Holds if this member implements an interface member explicitly.
   */
  predicate implementsExplicitInterface() {
    exists(getExplicitlyImplementedInterface())
  }

  /** Holds if this member can be overridden or implemented. */
  predicate isOverridableOrImplementable() {
     not isSealed()
     and
     not getDeclaringType().isSealed()
     and
     (
       isVirtual() or
       isOverride() or
       isAbstract() or
       getDeclaringType() instanceof Interface
     )
  }

  /** Gets the member that is immediately overridden by this member, if any. */
  Virtualizable getOverridee() {
    overrides(this, result)
    or
    // For accessors (which are `Callable`s), the extractor generates entries
    // in the `overrides` relation. However, we want the relation to be on
    // the declarations containing the accessors instead
    exists(Accessor accessorOverrider, Accessor accessorOverridee |
      accessorOverrider = this.(DeclarationWithAccessors).getAnAccessor() and
      accessorOverridee = result.(DeclarationWithAccessors).getAnAccessor() and
      overrides(accessorOverrider, accessorOverridee)
    )
  }

  /** Gets a member that immediately overrides this member, if any. */
  Virtualizable getAnOverrider() { this = result.getOverridee() }

  /** Holds if this member is overridden by some other member. */
  predicate isOverridden() { exists(getAnOverrider()) }

  /** Holds if this member overrides another member. */
  predicate overrides() { exists(getOverridee()) }

  /**
   * Gets the interface member that is immediately implemented by this member, if any.
   *
   * The type `t` is a type that implements the interface type in which
   * the result is declared, in such a way that this member is the
   * implementation of the result.
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
   * ```
   *
   * In the example above, the following (and nothing else) holds:
   * `A.M.getImplementee(B) = I.M` and
   * `C.M.getImplementee(C) = I.M`.
   */
  Virtualizable getImplementee(ValueOrRefType t) { implements(this, result, t) }

  /** Gets the interface member that is immediately implemented by this member, if any. */
  Virtualizable getImplementee() { result = getImplementee(_) }

  /**
   * Gets a member that immediately implements this interface member, if any.
   *
   * The type `t` is a type that implements the interface type in which
   * this member is declared, in such a way that the result is the
   * implementation of this member.
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
   * ```
   *
   * In the example above, the following (and nothing else) holds:
   * `I.M.getAnImplementor(B) = A.M` and
   * `I.M.getAnImplementor(C) = C.M`.
   */
  Virtualizable getAnImplementor(ValueOrRefType t) { this = result.getImplementee(t) }

  /** Gets a member that immediately implements this interface member, if any. */
  Virtualizable getAnImplementor() { this = result.getImplementee() }

  /**
   * Gets an interface member that is (transitively) implemented by this
   * member, if any. That is, either this member immediately implements
   * the interface member, or this member overrides (transitively) another
   * member that immediately implements the interface member.
   *
   * Note that this is generally *not* equivalent with
   * `getOverridee*().getImplementee()`, as the example below illustrates:
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
   * - If this member is `A.M` then `I.M = getAnUltimateImplementee()`.
   * - If this member is `C.M` then it is *not* the case that
   *   `I.M = getAnUltimateImplementee()`, because `C` is not a sub type of `I`.
   *   (An example where `getOverridee*().getImplementee()` would be incorrect.)
   * - If this member is `D.M` then `I.M = getAnUltimateImplementee()`.
   */
  Virtualizable getAnUltimateImplementee() {
    exists(Virtualizable implementation, ValueOrRefType implementationType |
      implements(implementation, result, implementationType) |
      this = implementation
      or
      getOverridee+() = implementation and
      getDeclaringType().getABaseType+() = implementationType
    )
  }

  /**
   * Gets a member that (transitively) implements this interface member,
   * if any. That is, either this interface member is immediately implemented
   * by the result, or the result overrides (transitively) another member that
   * immediately implements this interface member.
   *
   * Note that this is generally *not* equivalent with
   * `getImplementor().getAnOverrider*()` (see `getImplementee`).
   */
  Virtualizable getAnUltimateImplementor() { this = result.getAnUltimateImplementee() }

  /** Holds if this interface member is implemented by some other member. */
  predicate isImplemented() { exists(getAnImplementor()) }

  /** Holds if this member implements (transitively) an interface member. */
  predicate implements() { exists(getAnUltimateImplementee()) }

  /**
   * Holds if this member overrides or implements (reflexively, transitively)
   * `that` member.
   */
  predicate overridesOrImplementsOrEquals(Virtualizable that) {
    this = that or
    getOverridee+() = that or
    getAnUltimateImplementee() = that
  }
}

/**
 * A parameterizable declaration. Either a callable (`Callable`), a delegate
 * type (`DelegateType`), or an indexer (`Indexer`).
 */
class Parameterizable extends Declaration, @parameterizable {
  /** Gets a parameter of this declaration, if any. */
  Parameter getAParameter() { result = getParameter(_) }

  /** Gets the `i`th parameter of this declaration. */
  Parameter getParameter(int i) { params(result, _, _, i, _, this, _) }

  /** Gets the number of parameters of this declaration. */
  int getNumberOfParameters() { result = count(this.getAParameter()) }

  /** Holds if this declaration has no parameters. */
  predicate hasNoParameters() { not exists(this.getAParameter()) }

  /**
   * Gets the name of this parameter followed by its type, possibly prefixed
   * with `out`, `ref`, or `params`, where appropriate.
   */
  private string parameterTypeToString(int i) {
    exists(Parameter p, string prefix |
      p = getParameter(i) and
      result = prefix + p.getType().toStringWithTypes() |
      if p.isOut() then
        prefix = "out "
      else if p.isRef() then
        prefix = "ref "
      else if p.isParams() then
        prefix = "params "
      else
        prefix = ""
    )
  }

  /**
   * Gets the types of the parameters of this declaration as a
   * comma-separated string.
   */
  language [monotonicAggregates]
  string parameterTypesToString() {
    result = concat(int i |
      exists(getParameter(i)) |
      parameterTypeToString(i), ", " order by i asc
    )
  }
}
