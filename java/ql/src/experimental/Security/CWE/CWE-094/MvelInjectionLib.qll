import java
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.dataflow.TaintTracking
import DataFlow::PathGraph

/**
 * A taint-tracking configuration for unsafe user input
 * that is used to construct and evaluate a MVEL expression.
 */
class MvelInjectionConfig extends TaintTracking::Configuration {
  MvelInjectionConfig() { this = "MvelInjectionConfig" }

  override predicate isSource(DataFlow::Node source) { source instanceof RemoteFlowSource }

  override predicate isSink(DataFlow::Node sink) { sink instanceof MvelEvaluationSink }

  override predicate isAdditionalTaintStep(DataFlow::Node node1, DataFlow::Node node2) {
    expressionCompilationStep(node1, node2) or
    createExpressionCompilerStep(node1, node2) or
    expressionCompilerCompileStep(node1, node2) or
    createCompiledAccExpressionStep(node1, node2) or
    scriptCompileStep(node1, node2) or
    createMvelCompiledScriptStep(node1, node2)
  }
}

/**
 * A sink for EL injection vulnerabilities via MVEL,
 * i.e. methods that run evaluation of a MVEL expression.
 */
class MvelEvaluationSink extends DataFlow::ExprNode {
  MvelEvaluationSink() {
    exists(StaticMethodAccess ma, Method m | m = ma.getMethod() |
      m instanceof MvelEvalMethod and
      ma.getArgument(0) = asExpr()
    )
    or
    exists(MethodAccess ma, Method m | m = ma.getMethod() |
      m instanceof MvelScriptEngineEvaluationMethod and
      ma.getArgument(0) = asExpr()
    )
    or
    exists(MethodAccess ma, Method m | m = ma.getMethod() |
      (
        m instanceof ExecutableStatementEvaluationMethod or
        m instanceof CompiledExpressionEvaluationMethod or
        m instanceof CompiledAccExpressionEvaluationMethod or
        m instanceof AccessorEvaluationMethod or
        m instanceof CompiledScriptEvaluationMethod or
        m instanceof MvelCompiledScriptEvaluationMethod
      ) and
      (ma = asExpr() or ma.getQualifier() = asExpr())
    )
  }
}

/**
 * Holds if `node1` to `node2` is a dataflow step that compiles a MVEL expression
 * by callilng `MVEL.compileExpression(tainted)`.
 */
predicate expressionCompilationStep(DataFlow::Node node1, DataFlow::Node node2) {
  exists(StaticMethodAccess ma, Method m | ma.getMethod() = m |
    m.getDeclaringType() instanceof MVEL and
    m.hasName("compileExpression") and
    ma.getAnArgument() = node1.asExpr() and
    (node2.asExpr() = ma.getQualifier() or node2.asExpr() = ma)
  )
}

/**
 * Holds if `node1` to `node2` is a dataflow step creates `ExpressionCompiler`,
 * i.e. `new ExpressionCompiler(tainted)`.
 */
predicate createExpressionCompilerStep(DataFlow::Node node1, DataFlow::Node node2) {
  exists(ConstructorCall cc |
    cc.getConstructedType() instanceof ExpressionCompiler and
    (cc = node2.asExpr() or cc.getQualifier() = node2.asExpr()) and
    cc.getArgument(0) = node1.asExpr()
  )
}

/**
 * Holds if `node1` to `node2` is a dataflow step creates `CompiledAccExpression`,
 * i.e. `new CompiledAccExpression(tainted, ...)`.
 */
predicate createCompiledAccExpressionStep(DataFlow::Node node1, DataFlow::Node node2) {
  exists(ConstructorCall cc |
    cc.getConstructedType() instanceof CompiledAccExpression and
    (cc = node2.asExpr() or cc.getQualifier() = node2.asExpr()) and
    cc.getArgument(0) = node1.asExpr()
  )
}

predicate test() {
  exists(ConstructorCall cc | cc.getConstructedType() instanceof CompiledAccExpression)
}

/**
 * Holds if `node1` to `node2` is a dataflow step that compiles a MVEL expression
 * by calling `ExpressionCompiler.compile()`.
 */
predicate expressionCompilerCompileStep(DataFlow::Node node1, DataFlow::Node node2) {
  exists(MethodAccess ma, Method m | ma.getMethod() = m |
    m.getDeclaringType() instanceof ExpressionCompiler and
    m.hasName("compile") and
    ma = node2.asExpr() and
    ma.getQualifier() = node1.asExpr()
  )
}

/**
 * Holds if `node1` to `node2` is a dataflow step that compiles a script via `MvelScriptEngine`,
 * i.e. `engine.compile(tainted)` or `engine.compiledScript(tainted)`.
 */
predicate scriptCompileStep(DataFlow::Node node1, DataFlow::Node node2) {
  exists(MethodAccess ma, Method m | ma.getMethod() = m |
    m instanceof MvelScriptEngineCompilationnMethod and
    (ma = node2.asExpr() or ma.getQualifier() = node2.asExpr()) and
    ma.getArgument(0) = node1.asExpr()
  )
}

/**
 * Holds if `node1` to `node2` is a dataflow step creates `MvelCompiledScript`,
 * i.e. `new MvelCompiledScript(engine, tainted)`.
 */
predicate createMvelCompiledScriptStep(DataFlow::Node node1, DataFlow::Node node2) {
  exists(ConstructorCall cc |
    cc.getConstructedType() instanceof MvelCompiledScript and
    (cc = node2.asExpr() or cc.getQualifier() = node2.asExpr()) and
    cc.getArgument(1) = node1.asExpr()
  )
}

/**
 * Methods in the MVEL class that evaluate a MVEL expression.
 */
class MvelEvalMethod extends Method {
  MvelEvalMethod() {
    getDeclaringType() instanceof MVEL and
    (
      hasName("eval") or
      hasName("executeExpression") or
      hasName("evalToBoolean") or
      hasName("evalToString") or
      hasName("executeAllExpression") or
      hasName("executeSetExpression")
    )
  }
}

/**
 * Methods in `MVEL` class that compile a MVEL expression.
 */
class MvelCompileExpressionMethod extends Method {
  MvelCompileExpressionMethod() {
    getDeclaringType() instanceof MVEL and
    (
      hasName("compileExpression") or
      hasName("compileGetExpression") or
      hasName("compileSetExpression")
    )
  }
}

/**
 * Methods in `ExecutableStatement` that evaluate a MVEL expression.
 */
class ExecutableStatementEvaluationMethod extends Method {
  ExecutableStatementEvaluationMethod() {
    getDeclaringType() instanceof ExecutableStatement and
    hasName("getValue")
  }
}

/**
 * Methods in `CompiledExpression` that evaluate a MVEL expression.
 */
class CompiledExpressionEvaluationMethod extends Method {
  CompiledExpressionEvaluationMethod() {
    getDeclaringType() instanceof CompiledExpression and
    hasName("getDirectValue")
  }
}

/**
 * Methods in `CompiledAccExpression` that evaluate a MVEL expression.
 */
class CompiledAccExpressionEvaluationMethod extends Method {
  CompiledAccExpressionEvaluationMethod() {
    getDeclaringType() instanceof CompiledAccExpression and
    hasName("getValue")
  }
}

/**
 * Methods in `Accessor` that evaluate a MVEL expression.
 */
class AccessorEvaluationMethod extends Method {
  AccessorEvaluationMethod() {
    getDeclaringType() instanceof Accessor and
    hasName("getValue")
  }
}

/**
 * Methods in `MvelScriptEngine` that evaluate a MVEL expression.
 */
class MvelScriptEngineEvaluationMethod extends Method {
  MvelScriptEngineEvaluationMethod() {
    getDeclaringType() instanceof MvelScriptEngine and
    (hasName("eval") or hasName("evaluate"))
  }
}

/**
 * Methods in `MvelScriptEngine` that compile a MVEL expression.
 */
class MvelScriptEngineCompilationnMethod extends Method {
  MvelScriptEngineCompilationnMethod() {
    getDeclaringType() instanceof MvelScriptEngine and
    (hasName("compile") or hasName("compiledScript"))
  }
}

/**
 * Methods in `CompiledScript` that evaluate a MVEL expression.
 */
class CompiledScriptEvaluationMethod extends Method {
  CompiledScriptEvaluationMethod() {
    getDeclaringType() instanceof CompiledScript and
    hasName("eval")
  }
}

/**
 * Methods in `MvelCompiledScript` that evaluate a MVEL expression.
 */
class MvelCompiledScriptEvaluationMethod extends Method {
  MvelCompiledScriptEvaluationMethod() {
    getDeclaringType() instanceof MvelCompiledScript and
    hasName("eval")
  }
}

class MVEL extends RefType {
  MVEL() { hasQualifiedName("org.mvel2", "MVEL") }
}

class ExpressionCompiler extends RefType {
  ExpressionCompiler() { hasQualifiedName("org.mvel2.compiler", "ExpressionCompiler") }
}

class ExecutableStatement extends RefType {
  ExecutableStatement() { hasQualifiedName("org.mvel2.compiler", "ExecutableStatement") }
}

class CompiledExpression extends RefType {
  CompiledExpression() { hasQualifiedName("org.mvel2.compiler", "CompiledExpression") }
}

class CompiledAccExpression extends RefType {
  CompiledAccExpression() { hasQualifiedName("org.mvel2.compiler", "CompiledAccExpression") }
}

class Accessor extends RefType {
  Accessor() { hasQualifiedName("org.mvel2.compiler", "Accessor") }
}

class CompiledScript extends RefType {
  CompiledScript() { hasQualifiedName("javax.script", "CompiledScript") }
}

class MvelScriptEngine extends RefType {
  MvelScriptEngine() { hasQualifiedName("org.mvel2.jsr223", "MvelScriptEngine") }
}

class MvelCompiledScript extends RefType {
  MvelCompiledScript() { hasQualifiedName("org.mvel2.jsr223", "MvelCompiledScript") }
}
