/**
 * @name Assembly path injection
 * @description Loading a .NET assembly based on a path constructed from user-controlled sources
 *              may allow a malicious user to load code which modifies the program in unintended
 *              ways.
 * @kind problem
 * @id cs/assembly-path-injection
 * @problem.severity error
 * @tags security
 *       external/cwe/cwe-114
 */
/*
 * consider: @precision high
 */

import csharp
import semmle.code.csharp.dataflow.flowsources.Remote

class MainMethod extends Method {
  MainMethod() {
    this.hasName("Main") and
    this.isStatic() and
    (this.getReturnType() instanceof VoidType or this.getReturnType() instanceof IntType) and
    if this.getNumberOfParameters() = 1
    then this.getParameter(0).getType().(ArrayType).getElementType() instanceof StringType
    else this.getNumberOfParameters() = 0
  }
}

/**
 * A taint-tracking configuration for untrusted user input used to load a DLL.
 */
class TaintTrackingConfiguration extends TaintTracking::Configuration {
  TaintTrackingConfiguration() { this = "DLLInjection" }

  override predicate isSource(DataFlow::Node source) {
    source instanceof RemoteFlowSource or
    source.asExpr() = any(MainMethod main).getParameter(0).getAnAccess()
  }

  override predicate isSink(DataFlow::Node sink) {
    exists(MethodCall mc, string name, int arg |
      mc.getTarget().getName().matches(name) and
      mc
          .getTarget()
          .getDeclaringType()
          .getABaseType*()
          .hasQualifiedName("System.Reflection.Assembly") and
      mc.getArgument(arg) = sink.asExpr()
    |
      name = "LoadFrom" and arg = 0 and mc.getNumberOfArguments() = [1 .. 2]
      or
      name = "LoadFile" and arg = 0
      or
      name = "LoadWithPartialName" and arg = 0
      or
      name = "UnsafeLoadFrom" and arg = 0
    )
  }
}

from TaintTrackingConfiguration c, DataFlow::Node source, DataFlow::Node sink
where c.hasFlow(source, sink)
select sink, "$@ flows to here and is used as the path to dynamically load an assembly.", source,
  "User-provided value"
