/**
 * Provides classes for working with Google Closure code.
 */

import javascript

/**
 * A call to a function in the `goog` namespace such as `goog.provide` or `goog.load`.
 */
class GoogFunctionCall extends CallExpr {
  GoogFunctionCall() {
    exists(GlobalVariable gv | gv.getName() = "goog" |
      this.getCallee().(DotExpr).getBase() = gv.getAnAccess()
    )
  }

  /** Gets the name of the invoked function. */
  string getFunctionName() { result = getCallee().(DotExpr).getPropertyName() }
}

/**
 * An expression statement consisting of a call to a function
 * in the `goog` namespace.
 */
class GoogFunctionCallStmt extends ExprStmt {
  GoogFunctionCallStmt() { super.getExpr() instanceof GoogFunctionCall }

  override GoogFunctionCall getExpr() { result = super.getExpr() }

  /** Gets the name of the invoked function. */
  string getFunctionName() { result = getExpr().getFunctionName() }

  /** Gets the `i`th argument to the invoked function. */
  Expr getArgument(int i) { result = getExpr().getArgument(i) }

  /** Gets an argument to the invoked function. */
  Expr getAnArgument() { result = getArgument(_) }
}

private abstract class GoogNamespaceRef extends ExprOrStmt {
  abstract string getNamespaceId();
}

/**
 * A call to `goog.provide`.
 */
class GoogProvide extends GoogFunctionCallStmt, GoogNamespaceRef {
  GoogProvide() { getFunctionName() = "provide" }

  /** Gets the identifier of the namespace created by this call. */
  override string getNamespaceId() { result = getArgument(0).(ConstantString).getStringValue() }
}

/**
 * A call to `goog.require`.
 */
class GoogRequire extends GoogFunctionCall, GoogNamespaceRef {
  GoogRequire() { getFunctionName() = "require" }

  /** Gets the identifier of the namespace imported by this call. */
  override string getNamespaceId() { result = getArgument(0).(ConstantString).getStringValue() }
}

private class GoogRequireImport extends GoogRequire, Import {
  /** Gets the module in which this import appears. */
  override Module getEnclosingModule() { result = getTopLevel() }

  /** Gets the (unresolved) path that this import refers to. */
  override PathExpr getImportedPath() {
    result = getArgument(0)
  }
}

/**
 * A call to `goog.module` or `goog.declareModuleId`.
 */
class GoogModuleDeclaration extends GoogFunctionCallStmt, GoogNamespaceRef {
  GoogModuleDeclaration() {
    getFunctionName() = "module" or
    getFunctionName() = "declareModuleId"
  }

  /** Gets the identifier of the namespace imported by this call. */
  override string getNamespaceId() { result = getArgument(0).(ConstantString).getStringValue() }
}

/**
 * A module using the Closure module system, declared using `goog.module()` or `goog.declareModuleId()`.
 */
class ClosureModule extends Module {
  ClosureModule() {
    getAChildStmt() instanceof GoogModuleDeclaration
  }

  /**
   * Gets the call to `goog.module()` or `goog.declareModuleId` in this module.
   */
  GoogModuleDeclaration getModuleDeclaration() {
    result = getAChildStmt()
  }

  /**
   * Gets the namespace of this module.
   */
  string getNamespaceId() { result = getModuleDeclaration().getNamespaceId() }

  override Module getAnImportedModule() {
    exists (GoogRequireImport imprt | 
      imprt.getEnclosingModule() = this and
      result.(ClosureModule).getNamespaceId() = imprt.getNamespaceId()
    )
  }

  /**
   * Gets the top-level `exports` variable in this module, if this module is defined by
   * a `good.module` call.
   *
   * This variable denotes the object exported from this module.
   *
   * Has no result for ES6 modules using `goog.declareModuleId`.
   */
  Variable getExportsVariable() {
    getModuleDeclaration().getFunctionName() = "module" and
    result.getScope() = this.getScope() and
    result.getName() = "exports"
  }

  override predicate exports(string name, ASTNode export) {
    // exports.foo = bar
    export.(AssignExpr).getLhs().(PropAccess).accesses(getExportsVariable().getAnAccess(), name)
    or
    // exports = { foo: bar }
    exists (VarDef def |
      def.getTarget() = getExportsVariable().getAReference() and
      def.getSource().(ObjectExpr).getPropertyByName(name) = export
    )
  }
}

/**
 * A global Closure script, that is, a toplevel that is executed in the global scope and
 * contains a toplevel call to `goog.provide` or `goog.require`.
 */
class ClosureScript extends TopLevel {
  ClosureScript() {
    not this instanceof ClosureModule and
    getAChildStmt() instanceof GoogProvide or
    getAChildStmt().(ExprStmt).getExpr() instanceof GoogRequire
  }

  /** Gets the identifier of a namespace required by this module. */
  string getARequiredNamespace() { result = getAChildStmt().(ExprStmt).getExpr().(GoogRequire).getNamespaceId() }

  /** Gets the identifer of a namespace provided by this module. */
  string getAProvidedNamespace() { result = getAChildStmt().(GoogProvide).getNamespaceId() }
}

/**
 * Holds if `name` is a closure namespace, including proper namespace prefixes.
 */
pragma[noinline]
predicate isClosureLibraryNamespacePath(string name) {
  exists (string namespace | namespace = any(GoogNamespaceRef provide).getNamespaceId() |
    name = namespace.substring(0, namespace.indexOf("."))
    or
    name = namespace
  )
}

/**
 * Gets the closure namespace path addressed by the given dataflow node, if any.
 */
string getClosureLibraryAccessPath(DataFlow::SourceNode node) {
  isClosureLibraryNamespacePath(result) and
  node = DataFlow::globalVarRef(result)
  or
  isClosureLibraryNamespacePath(result) and
  exists (DataFlow::PropRead read | node = read |
    result = getClosureLibraryAccessPath(read.getBase().getALocalSource()) + "." + read.getPropertyName()
  )
  or
  // Associate an access path with the immediate RHS of a store on a closure namespace.
  // This is to support patterns like:
  // foo.bar = { baz() {} }
  exists (DataFlow::PropWrite write |
    node = write.getRhs() and
    result = getWrittenClosureLibraryAccessPath(write)
  )
  or
  result = node.asExpr().(GoogRequire).getNamespaceId()
}

/**
 * Gets the closure namespace path written to by the given property write, if any.
 */
string getWrittenClosureLibraryAccessPath(DataFlow::PropWrite node) {
  result = getClosureLibraryAccessPath(node.getBase().getALocalSource()) + "." + node.getPropertyName()
}
