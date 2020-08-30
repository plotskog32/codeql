/**
 * Models imports through the NPM `lazy-cache` package.
 */

import javascript

module LazyCache {
  /**
   * DEPRECATED. DO NOT USE.
   *
   * A lazy-cache object, usually created through an expression of form `require('lazy-cache')(require)`.
   */
  deprecated class LazyCacheObject extends DataFlow::SourceNode {
    LazyCacheObject() {
      // Use `require` directly instead of `moduleImport` to avoid recursion.
      // For the same reason, avoid `Import.getImportedPath`.
      exists(Require req |
        req.getArgument(0).getStringValue() = "lazy-cache" and
        this = req.flow().(DataFlow::SourceNode).getAnInvocation()
      )
    }
  }

  /**
   * A variable containing a lazy-cache object.
   */
  class LazyCacheVariable extends LocalVariable {
    LazyCacheVariable() {
      // To avoid recursion, this should not depend on `SourceNode`.
      exists(Require req |
        req.getArgument(0).getStringValue() = "lazy-cache" and
        getAnAssignedExpr().(CallExpr).getCallee() = req
      )
    }
  }

  /**
   * An import through `lazy-cache`.
   */
  class LazyCacheImport extends CallExpr, Import {
    LazyCacheVariable cache;

    LazyCacheImport() { getCallee() = cache.getAnAccess() }

    /** Gets the name of the package as it's exposed on the lazy-cache object. */
    string getLocalAlias() {
      result = getArgument(1).getStringValue()
      or
      not exists(getArgument(1)) and
      result = getArgument(0).getStringValue()
    }

    override Module getEnclosingModule() { result = getTopLevel() }

    override PathExpr getImportedPath() { result = getArgument(0) }

    private LazyCacheVariable getVariable() { result = cache }

    pragma[noopt]
    override DataFlow::Node getImportedModuleNode() {
      this instanceof LazyCacheImport and
      result = this.flow()
      or
      exists(LazyCacheVariable variable, Expr base, PropAccess access, string localName |
        // To avoid recursion, this should not depend on `SourceNode`.
        variable = getVariable() and
        base = variable.getAnAccess() and
        access.getBase() = base and
        localName = getLocalAlias() and
        access.getPropertyName() = localName and
        result = access.flow()
      )
    }
  }

  /** A constant path element appearing in a call to a lazy-cache object. */
  private class LazyCachePathExpr extends PathExpr, ConstantString {
    LazyCachePathExpr() { this = any(LazyCacheImport rp).getArgument(0) }

    override string getValue() { result = getStringValue() }
  }
}
