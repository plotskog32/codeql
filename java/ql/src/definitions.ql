/**
 * @name Jump-to-definition links
 * @description Generates use-definition pairs that provide the data
 *              for jump-to-definition in the code viewer.
 * @kind definitions
 * @id java/jump-to-definition
 */

import java

/**
 * Restricts the location of a method access to the method identifier only,
 * excluding its qualifier, type arguments and arguments.
 *
 * If there is any whitespace between the method identifier and its first argument,
 * or between the method identifier and its qualifier (or last type argument, if any),
 * the location may be slightly inaccurate and include such whitespace,
 * but it should suffice for the purpose of avoiding overlapping definitions.
 */
class LocationOverridingMethodAccess extends MethodAccess {
  override predicate hasLocationInfo(string path, int sl, int sc, int el, int ec) {
    exists(MemberRefExpr e | e.getReferencedCallable() = getMethod() |
      exists(int elRef, int ecRef | e.hasLocationInfo(path, _, _, elRef, ecRef) |
        sl = elRef and
        sc = ecRef - getMethod().getName().length() + 1 and
        el = elRef and
        ec = ecRef
      )
    )
    or
    not exists(MemberRefExpr e | e.getReferencedCallable() = getMethod()) and
    exists(int slSuper, int scSuper, int elSuper, int ecSuper |
      super.hasLocationInfo(path, slSuper, scSuper, elSuper, ecSuper)
    |
      (
        if (exists(getTypeArgument(_)))
        then
          exists(Location locTypeArg |
            locTypeArg = getTypeArgument(count(getTypeArgument(_)) - 1).getLocation()
          |
            sl = locTypeArg.getEndLine() and
            sc = locTypeArg.getEndColumn() + 2
          )
        else (
          if exists(getQualifier())
          then
            // Note: this needs to be the original (full) location of the qualifier, not the modified one.
            exists(Location locQual | locQual = getQualifier().getLocation() |
              sl = locQual.getEndLine() and
              sc = locQual.getEndColumn() + 2
            )
          else (
            sl = slSuper and
            sc = scSuper
          )
        )
      ) and
      (
        if (getNumArgument() > 0)
        then
          // Note: this needs to be the original (full) location of the first argument, not the modified one.
          exists(Location locArg | locArg = getArgument(0).getLocation() |
            el = locArg.getStartLine() and
            ec = locArg.getStartColumn() - 2
          )
        else (
          el = elSuper and
          ec = ecSuper - 2
        )
      )
    )
  }
}

/**
 * Restricts the location of a type access to exclude
 * the type arguments and qualifier, if any.
 */
class LocationOverridingTypeAccess extends TypeAccess {
  override predicate hasLocationInfo(string path, int sl, int sc, int el, int ec) {
    exists(int slSuper, int scSuper, int elSuper, int ecSuper |
      super.hasLocationInfo(path, slSuper, scSuper, elSuper, ecSuper)
    |
      (
        if exists(getQualifier())
        then
          // Note: this needs to be the original (full) location of the qualifier, not the modified one.
          exists(Location locQual | locQual = getQualifier().getLocation() |
            sl = locQual.getEndLine() and
            sc = locQual.getEndColumn() + 2
          )
        else (
          sl = slSuper and
          sc = scSuper
        )
      ) and
      (
        if (exists(getTypeArgument(_)))
        then
          // Note: this needs to be the original (full) location of the first type argument, not the modified one.
          exists(Location locArg | locArg = getTypeArgument(0).getLocation() |
            el = locArg.getStartLine() and
            ec = locArg.getStartColumn() - 2
          )
        else (
          el = elSuper and
          ec = ecSuper
        )
      )
    )
  }
}

/**
 * Restricts the location of a field access to the name of the accessed field only,
 * excluding its qualifier.
 */
class LocationOverridingFieldAccess extends FieldAccess {
  override predicate hasLocationInfo(string path, int sl, int sc, int el, int ec) {
    super.hasLocationInfo(path, _, _, el, ec) and
    sl = el and
    sc = ec - (getField().getName().length()) + 1
  }
}

/**
 * Restricts the location of a single-type-import declaration to the name of the imported type only,
 * excluding the `import` keyword and the package name.
 */
class LocationOverridingImportType extends ImportType {
  override predicate hasLocationInfo(string path, int sl, int sc, int el, int ec) {
    exists(int slSuper, int scSuper, int elSuper, int ecSuper |
      super.hasLocationInfo(path, slSuper, scSuper, elSuper, ecSuper)
    |
      el = elSuper and
      ec = ecSuper - 1 and
      sl = el and
      sc = ecSuper - (getImportedType().getName().length())
    )
  }
}

/**
 * Restricts the location of a single-static-import declaration to the name of the imported member(s) only,
 * excluding the `import` keyword and the package name.
 */
class LocationOverridingImportStaticTypeMember extends ImportStaticTypeMember {
  override predicate hasLocationInfo(string path, int sl, int sc, int el, int ec) {
    exists(int slSuper, int scSuper, int elSuper, int ecSuper |
      super.hasLocationInfo(path, slSuper, scSuper, elSuper, ecSuper)
    |
      el = elSuper and
      ec = ecSuper - 1 and
      sl = el and
      sc = ecSuper - (getName().length())
    )
  }
}

Element definition(Element e, string kind) {
  e.(MethodAccess).getMethod().getSourceDeclaration() = result and kind = "M"
  or
  e.(TypeAccess).getType().(RefType).getSourceDeclaration() = result and kind = "T"
  or
  exists(Variable v | v = e.(VarAccess).getVariable() |
    result = v.(Field).getSourceDeclaration() or
    result = v.(Parameter).getSourceDeclaration() or
    result = v.(LocalVariableDecl)
  ) and
  kind = "V"
  or
  e.(ImportType).getImportedType() = result and kind = "I"
  or
  e.(ImportStaticTypeMember).getAMemberImport() = result and kind = "I"
}

predicate dummyVarAccess(VarAccess va) {
  exists(AssignExpr ae, InitializerMethod im |
    ae.getDest() = va and
    ae.getParent() = im.getBody().getAChild()
  )
}

predicate dummyTypeAccess(TypeAccess ta) {
  exists(FunctionalExpr e |
    e.getAnonymousClass().getClassInstanceExpr().getTypeName() = ta.getParent*()
  )
}

from Element e, Element def, string kind
where
  def = definition(e, kind) and
  def.fromSource() and
  e.fromSource() and
  not dummyVarAccess(e) and
  not dummyTypeAccess(e)
select e, def, kind
