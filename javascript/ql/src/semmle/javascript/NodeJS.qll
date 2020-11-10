/** Provides classes for working with Node.js modules. */

import javascript
private import NodeModuleResolutionImpl

/**
 * A Node.js module.
 *
 * Example:
 *
 * ```
 * const fs = require('fs');
 * for (var i=2;i<process.argv.length; ++i)
 *   process.stdout.write(fs.readFileSync(process.argv[i], 'utf8'));
 * ```
 */
class NodeModule extends Module {
  NodeModule() {
    is_module(this) and
    is_nodejs(this)
  }

  /** Gets the `module` variable of this module. */
  Variable getModuleVariable() { result = getScope().getVariable("module") }

  /** Gets the `exports` variable of this module. */
  Variable getExportsVariable() { result = getScope().getVariable("exports") }

  /** Gets the scope induced by this module. */
  override ModuleScope getScope() { result.getScopeElement() = this }

  /**
   * Gets an abstract value representing one or more values that may flow
   * into this module's `module.exports` property.
   */
  DefiniteAbstractValue getAModuleExportsValue() {
    exists(AbstractProperty moduleExports |
      moduleExports.getBase().(AbstractModuleObject).getModule() = this and
      moduleExports.getPropertyName() = "exports"
    |
      result = moduleExports.getAValue()
    )
  }

  /**
   * Gets an expression that is an alias for `module.exports`.
   * For performance this predicate only computes relevant expressions.
   * So if using this predicate - consider expanding the list of relevant expressions.
   */
  pragma[noinline]
  DataFlow::Node getAModuleExportsNode() {
    (
      // A bit of manual magic
      result = any(DataFlow::PropWrite w | exists(w.getPropertyName())).getBase()
      or
      result = DataFlow::valueNode(any(PropAccess p | exists(p.getPropertyName())).getBase())
      or
      result = DataFlow::valueNode(any(ObjectExpr obj))
    ) and
    result.analyze().getAValue() = getAModuleExportsValue()
  }

  /** Gets a symbol exported by this module. */
  override string getAnExportedSymbol() {
    result = super.getAnExportedSymbol()
    or
    result = getAnImplicitlyExportedSymbol()
    or
    // getters and the like.
    exists(DataFlow::PropWrite pwn |
      pwn.getBase() = this.getAModuleExportsNode() and
      result = pwn.getPropertyName()
    )
  }

  override DataFlow::Node getAnExportedValue(string name) {
    // a property write whose base is `exports` or `module.exports`
    exists(DataFlow::PropWrite pwn | result = pwn.getRhs() |
      pwn.getBase() = getAModuleExportsNode() and
      name = pwn.getPropertyName()
    )
    or
    // a re-export using spread-operator. E.g. `const foo = require("./foo"); module.exports = {bar: bar, ...foo};`
    exists(ObjectExpr obj | obj = getAModuleExportsNode().asExpr() |
      result =
        obj
            .getAProperty()
            .(SpreadProperty)
            .getInit()
            .(SpreadElement)
            .getOperand()
            .flow()
            .getALocalSource()
            .asExpr()
            .(Import)
            .getImportedModule()
            .getAnExportedValue(name)
    )
    or
    // an externs definition (where appropriate)
    exists(PropAccess pacc | result = DataFlow::valueNode(pacc) |
      pacc.getBase() = getAModuleExportsNode().asExpr() and
      name = pacc.getPropertyName() and
      isExterns() and
      exists(pacc.getDocumentation())
    )
  }

  /** Gets a symbol that the module object inherits from its prototypes. */
  private string getAnImplicitlyExportedSymbol() {
    exists(ExternalConstructor ec | ec = getPrototypeOfExportedExpr() |
      result = ec.getAMember().getName()
      or
      ec instanceof FunctionExternal and result = "prototype"
      or
      ec instanceof ArrayExternal and
      exists(NumberLiteral nl | result = nl.getValue() and exists(result.toInt()))
    )
  }

  /** Gets an externs declaration of the prototype object of a value exported by this module. */
  private ExternalConstructor getPrototypeOfExportedExpr() {
    exists(AbstractValue exported | exported = getAModuleExportsValue() |
      result instanceof ObjectExternal
      or
      exported instanceof AbstractFunction and result instanceof FunctionExternal
      or
      exported instanceof AbstractOtherObject and result instanceof ArrayExternal
    )
  }

  override predicate searchRoot(PathExpr path, Folder searchRoot, int priority) {
    path.getEnclosingModule() = this and
    exists(string pathval | pathval = path.getValue() |
      // paths starting with `./` or `../` are resolved relative to the importing
      // module's folder
      pathval.regexpMatch("\\.\\.?(/.*)?") and
      (searchRoot = getFile().getParentContainer() and priority = 0)
      or
      // paths starting with `/` are resolved relative to the file system root
      pathval.matches("/%") and
      (searchRoot.getBaseName() = "" and priority = 0)
      or
      // paths that do not start with `./`, `../` or `/` are resolved relative
      // to `node_modules` folders
      not pathval.regexpMatch("\\.\\.?(/.*)?|/.*") and
      findNodeModulesFolder(getFile().getParentContainer(), searchRoot, priority)
    )
  }
}

/**
 * Holds if `nodeModules` is a folder of the form `<prefix>/node_modules`, where
 * `<prefix>` is a (not necessarily proper) prefix of `f` and does not end in `/node_modules`,
 * and `distance` is the number of path elements of `f` that are missing from `<prefix>`.
 *
 * This predicate implements the `NODE_MODULES_PATHS` procedure from the
 * [specification of `require.resolve`](https://nodejs.org/api/modules.html#modules_all_together).
 *
 * For example, if `f` is `/a/node_modules/b`, we get the following results:
 *
 * <table border="1">
 * <tr><th><code>nodeModules</code></th><th><code>distance</code></th></tr>
 * <tr><td><code>/a/node_modules/b/node_modules</code></td><td>0</td></tr>
 * <tr><td><code>/a/node_modules</code></td><td>2</td></tr>
 * <tr><td><code>/node_modules</code></td><td>3</td></tr>
 * </table>
 */
predicate findNodeModulesFolder(Folder f, Folder nodeModules, int distance) {
  nodeModules = f.getFolder("node_modules") and
  not f.getBaseName() = "node_modules" and
  distance = 0
  or
  findNodeModulesFolder(f.getParentContainer(), nodeModules, distance - 1)
}

/**
 * A Node.js `require` variable.
 */
private class RequireVariable extends Variable {
  RequireVariable() {
    this = any(ModuleScope m).getVariable("require")
    or
    // cover cases where we failed to detect Node.js code
    this.(GlobalVariable).getName() = "require"
    or
    // track through assignments to other variables
    this.getAnAssignedExpr().(VarAccess).getVariable() instanceof RequireVariable
  }
}

/**
 * Holds if module `m` is in file `f`.
 */
private predicate moduleInFile(Module m, File f) { m.getFile() = f }

/**
 * Holds if `nd` may refer to `require`, either directly or modulo local data flow.
 */
cached
private predicate isRequire(DataFlow::Node nd) {
  nd.asExpr() = any(RequireVariable req).getAnAccess() and
  // `mjs` files explicitly disallow `require`
  not nd.getFile().getExtension() = "mjs"
  or
  isRequire(nd.getAPredecessor())
  or
  // `import { createRequire } from 'module';`.
  // specialized to ES2015 modules to avoid recursion in the `DataFlow::moduleImport()` predicate and to avoid
  // negative recursion between `Import.getImportedModuleNode()` and `Import.getImportedModule()`.
  exists(ImportDeclaration imp, DataFlow::SourceNode baseObj |
    imp.getImportedPath().getValue() = "module"
  |
    baseObj =
      [
        DataFlow::destructuredModuleImportNode(imp),
        DataFlow::valueNode(imp.getASpecifier().(ImportNamespaceSpecifier))
      ] and
    nd = baseObj.getAPropertyRead("createRequire").getACall()
  )
}

/**
 * A `require` import.
 *
 * Example:
 *
 * ```
 * require('fs')
 * ```
 */
class Require extends CallExpr, Import {
  Require() { isRequire(getCallee().flow()) }

  override PathExpr getImportedPath() { result = getArgument(0) }

  override Module getEnclosingModule() { this = result.getAnImport() }

  override Module resolveImportedPath() {
    moduleInFile(result, load(min(int prio | moduleInFile(_, load(prio)))))
    or
    not exists(Module mod | moduleInFile(mod, load(_))) and
    result = Import.super.resolveImportedPath()
  }

  /**
   * Gets the file that is imported by this `require`.
   *
   * The result can be a JavaScript file, a JSON file or a `.node` file.
   * Externs files are not treated differently from other files by this predicate.
   */
  File getImportedFile() { result = load(min(int prio | exists(load(prio)))) }

  /**
   * Gets the file that this `require` refers to (which may not be a JavaScript file),
   * using the root folder of priority `priority`.
   *
   * This predicate implements the specification of
   * [`require.resolve`](https://nodejs.org/api/modules.html#modules_all_together),
   * modified to allow additional JavaScript file extensions, such as `ts` and `jsx`.
   *
   * Module resolution order is modeled using the `priority` parameter as follows.
   *
   * Each candidate folder in which the path may be resolved is assigned
   * a priority (this is actually done by `Module.searchRoot`, but we explain it
   * here for completeness):
   *
   *   - if the path starts with `'./'`, `'../'`, or `/`, it has a single candidate
   *     folder (the enclosing folder of the module for the former two, the file
   *     system root for the latter) of priority 0
   *   - otherwise, candidate folders are folders of the form `<prefix>/node_modules`
   *     such that `<prefix>` is a (not necessarily proper) ancestor of the enclosing
   *     folder of the module which is not itself named `node_modules`; the priority
   *     of a candidate folder is the number of steps from the enclosing folder of
   *     the module to `<prefix>`.
   *
   * To resolve an import of a path `p`, we consider each candidate folder `c` with
   * priority `r` and resolve the import to the following files if they exist
   * (in order of priority):
   *
   * <ul>
   * <li> the file `c/p`;
   * <li> the file `c/p.{tsx,ts,jsx,es6,es,mjs,cjs}`;
   * <li> the file `c/p.js`;
   * <li> the file `c/p.json`;
   * <li> the file `c/p.node`;
   * <li> if `c/p` is a folder:
   *      <ul>
   *      <li> if `c/p/package.json` exists and specifies a `main` module `m`:
   *        <ul>
   *        <li> the file `c/p/m`;
   *        <li> the file `c/p/m.{tsx,ts,jsx,es6,es,mjs,cjs}`;
   *        <li> the file `c/p/m.js`;
   *        <li> the file `c/p/m.json`;
   *        <li> the file `c/p/m.node`;
   *        </ul>
   *      <li> the file `c/p/index.{tsx,ts,jsx,es6,es,mjs,cjs}`;
   *      <li> the file `c/p/index.js`;
   *      <li> the file `c/p/index.json`;
   *      <li> the file `c/p/index.node`.
   *      </ul>
   * </ul>
   *
   * The first four steps are factored out into predicate `loadAsFile`,
   * the remainder into `loadAsDirectory`; both make use of an auxiliary
   * predicate `tryExtensions` that handles the repeated distinction between
   * `.js`, `.json` and `.node`.
   */
  private File load(int priority) {
    exists(int r | getEnclosingModule().searchRoot(getImportedPath(), _, r) |
      result = loadAsFile(this, r, priority - prioritiesPerCandidate() * r) or
      result =
        loadAsDirectory(this, r,
          priority - (prioritiesPerCandidate() * r + numberOfExtensions() + 1))
    )
  }

  override DataFlow::Node getImportedModuleNode() { result = DataFlow::valueNode(this) }
}

/** An argument to `require` or `require.resolve`, considered as a path expression. */
private class RequirePath extends PathExprCandidate {
  RequirePath() {
    this = any(Require req).getArgument(0)
    or
    exists(MethodCallExpr reqres |
      isRequire(reqres.getReceiver().flow()) and
      reqres.getMethodName() = "resolve" and
      this = reqres.getArgument(0)
    )
  }
}

/** A constant path element appearing in a call to `require` or `require.resolve`. */
private class ConstantRequirePathElement extends PathExpr, ConstantString {
  ConstantRequirePathElement() { this = any(RequirePath rp).getAPart() }

  override string getValue() { result = getStringValue() }
}

/** A `__dirname` path expression. */
private class DirNamePath extends PathExpr, VarAccess {
  DirNamePath() {
    getName() = "__dirname" and
    getVariable().getScope() instanceof ModuleScope
  }

  override string getValue() { result = getFile().getParentContainer().getAbsolutePath() }
}

/** A `__filename` path expression. */
private class FileNamePath extends PathExpr, VarAccess {
  FileNamePath() {
    getName() = "__filename" and
    getVariable().getScope() instanceof ModuleScope
  }

  override string getValue() { result = getFile().getAbsolutePath() }
}

/**
 * A path expression of the form `path.join(p, "...")` where
 * `p` is also a path expression.
 */
private class JoinedPath extends PathExpr, @call_expr {
  JoinedPath() {
    exists(MethodCallExpr call | call = this |
      call.getReceiver().(VarAccess).getName() = "path" and
      call.getMethodName() = "join" and
      call.getNumArgument() = 2 and
      call.getArgument(0) instanceof PathExpr and
      call.getArgument(1) instanceof ConstantString
    )
  }

  override string getValue() {
    exists(CallExpr call, PathExpr left, ConstantString right |
      call = this and
      left = call.getArgument(0) and
      right = call.getArgument(1)
    |
      result = left.getValue() + "/" + right.getStringValue()
    )
  }
}

/**
 * A reference to the special `module` variable.
 *
 * Example:
 *
 * ```
 * module
 * ```
 */
class ModuleAccess extends VarAccess {
  ModuleAccess() { exists(ModuleScope ms | this = ms.getVariable("module").getAnAccess()) }
}
