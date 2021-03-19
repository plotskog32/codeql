/**
 * EXPERIMENTAL. This API may change in the future.
 *
 * Provides predicates for working with values exported from a package.
 */

import javascript

/**
 * Gets a parameter that is a library input to a top-level package.
 */
DataFlow::ParameterNode getALibraryInputParameter() {
  exists(int bound, DataFlow::FunctionNode func |
    func = getAValueExportedByPackage().getABoundFunctionValue(bound) and
    result = func.getParameter(any(int arg | arg >= bound))
  )
}

/**
 * Gets the number of occurrences of "/" in `path`.
 */
bindingset[path]
private int countSlashes(string path) { result = count(path.splitAt("/")) - 1 }

/**
 * Gets the topmost named package.json that appears in the project.
 *
 * There can be multiple results if the there exists multiple package.json that are equally deeply nested in the folder structure.
 * Results are limited to package.json files that are at most nested 2 directories deep.
 */
PackageJSON getTopmostPackageJSON() {
  result =
    min(PackageJSON j |
      countSlashes(j.getFile().getRelativePath()) <= 3 and
      exists(j.getPackageName())
    |
      j order by countSlashes(j.getFile().getRelativePath())
    )
}

/**
 * Gets a value exported by the main module from one of the topmost `package.json` files (see `getTopmostPackageJSON`).
 * The value is either directly the `module.exports` value, a nested property of `module.exports`, or a method on an exported class.
 */
DataFlow::Node getAValueExportedByPackage() {
  result = getAnExportFromModule(getTopmostPackageJSON().getMainModule())
  or
  result = getAValueExportedByPackage().(DataFlow::PropWrite).getRhs()
  or
  exists(DataFlow::SourceNode callee |
    callee = getAValueExportedByPackage().(DataFlow::NewNode).getCalleeNode().getALocalSource()
  |
    result = callee.getAPropertyRead("prototype").getAPropertyWrite().getRhs()
    or
    result = callee.(DataFlow::ClassNode).getAnInstanceMethod()
  )
  or
  result = getAValueExportedByPackage().getALocalSource()
  or
  result = getAValueExportedByPackage().(DataFlow::SourceNode).getAPropertyReference()
  or
  exists(Module mod |
    mod = getAValueExportedByPackage().getEnclosingExpr().(Import).getImportedModule()
  |
    result = getAnExportFromModule(mod)
  )
  or
  exists(DataFlow::ClassNode cla | cla = getAValueExportedByPackage() |
    result = cla.getAnInstanceMethod() or
    result = cla.getAStaticMethod() or
    result = cla.getConstructor()
  )
  or
  // *****
  // Various standard library methods for transforming exported objects.
  // *****
  //
  // Object.defineProperties
  exists(DataFlow::MethodCallNode call |
    call = DataFlow::globalVarRef("Object").getAMethodCall("defineProperties") and
    [call, call.getArgument(0)] = getAValueExportedByPackage() and
    result = call.getArgument(any(int i | i > 0))
  )
  or
  // Object.defineProperty
  exists(CallToObjectDefineProperty call |
    [call, call.getBaseObject()] = getAValueExportedByPackage()
  |
    result = call.getPropertyDescriptor().getALocalSource().getAPropertyReference("value")
    or
    result =
      call.getPropertyDescriptor()
          .getALocalSource()
          .getAPropertyReference("get")
          .(DataFlow::FunctionNode)
          .getAReturn()
  )
  or
  // Object.assign
  exists(ExtendCall assign |
    getAValueExportedByPackage() = [assign, assign.getDestinationOperand()] and
    result = assign.getASourceOperand()
  )
  or
  // Array.prototype.{map, reduce, entries, values}
  exists(DataFlow::MethodCallNode map |
    map.getMethodName() = ["map", "reduce", "entries", "values"] and
    map = getAValueExportedByPackage()
  |
    result = map.getArgument(0).getABoundFunctionValue(_).getAReturn()
    or
    // assuming that the receiver of the call is somehow exported
    result = map.getReceiver()
  )
  or
  // Object.{fromEntries, freeze, entries, values}
  exists(DataFlow::MethodCallNode freeze |
    freeze =
      DataFlow::globalVarRef("Object")
          .getAMethodCall(["fromEntries", "freeze", "seal", "entries", "values"])
  |
    freeze = getAValueExportedByPackage() and
    result = freeze.getArgument(0)
  )
}

/**
 * Gets an exported node from the module `mod`.
 */
private DataFlow::Node getAnExportFromModule(Module mod) {
  result.analyze().getAValue() = mod.(NodeModule).getAModuleExportsValue()
  or
  result = mod.(Closure::ClosureModule).getExportsVariable().getAnAssignedExpr().flow()
  or
  result.analyze().getAValue() = mod.(AmdModule).getDefine().getAModuleExportsValue()
  or
  result = mod.getAnExportedValue(_)
}
