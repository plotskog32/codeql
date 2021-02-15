/**
 * Provides classes and predicates for reasoning about [Next.js](https://www.npmjs.com/package/next).
 */

import javascript

/**
 * Provides classes and predicates modelling [Next.js](https://www.npmjs.com/package/next).
 */
private module NextJS {
  /**
   * Gets a `package.json` that depends on the `Next.js` library.
   */
  PackageJSON getANextPackage() { result.getDependencies().getADependency("next", _) }

  /**
   * Gets a "pages" folder in a `Next.js` application.
   * JavaScript files inside these folders are mapped to routes.
   */
  Folder getAPagesFolder() {
    result = getANextPackage().getFile().getParentContainer().getFolder("pages")
    or
    result = getAPagesFolder().getAFolder()
  }

  /**
   * Gets a module inside a "pages" folder where `fallback` from `getStaticPaths` is not set to false.
   * In such a module the `getStaticProps` method can be called with user-defined parameters.
   * If `fallback` is set to false, then only values defined by `getStaticPaths` are allowed.
   */
  Module getAModuleWithFallbackPaths() {
    result.getFile().getParentContainer() = getAPagesFolder() and
    exists(DataFlow::FunctionNode staticPaths, Expr fallback |
      staticPaths = result.getAnExportedValue("getStaticPaths").getAFunctionValue() and
      fallback =
        staticPaths.getAReturn().getALocalSource().getAPropertyWrite("fallback").getRhs().asExpr() and
      not fallback.(BooleanLiteral).getValue() = "false"
    )
  }

  /**
   * User defined path parameter in `Next.js`.
   */
  class NextParams extends RemoteFlowSource {
    NextParams() {
      this =
        getAModuleWithFallbackPaths()
            .getAnExportedValue("getStaticProps")
            .getAFunctionValue()
            .getParameter(0)
            .getAPropertyRead("params")
    }

    override string getSourceType() { result = "Next request parameter" }
  }
}
