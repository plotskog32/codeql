private import cpp
private import semmle.code.cpp.ir.IR
private import semmle.code.cpp.ir.dataflow.DataFlow
private import semmle.code.cpp.ir.dataflow.internal.DataFlowPrivate

Function viableImpl(CallInstruction call) { result = viableCallable(call) }

/**
 * Gets a function that might be called by `call`.
 */
Function viableCallable(CallInstruction call) {
  result = call.getStaticCallTarget()
  or
  // If the target of the call does not have a body in the snapshot, it might
  // be because the target is just a header declaration, and the real target
  // will be determined at run time when the caller and callee are linked
  // together by the operating system's dynamic linker. In case a _unique_
  // function with the right signature is present in the database, we return
  // that as a potential callee.
  exists(string qualifiedName, int nparams |
    callSignatureWithoutBody(qualifiedName, nparams, call) and
    functionSignatureWithBody(qualifiedName, nparams, result) and
    strictcount(Function other | functionSignatureWithBody(qualifiedName, nparams, other)) = 1
  )
  or
  // Virtual dispatch
  result = call.(VirtualDispatch::DataSensitiveCall).resolve()
}

/**
 * Provides virtual dispatch support compatible with the original
 * implementation of `semmle.code.cpp.security.TaintTracking`.
 */
private module VirtualDispatch {
  /** A call that may dispatch differently depending on the qualifier value. */
  abstract class DataSensitiveCall extends DataFlowCall {
    abstract DataFlow::Node getSrc();

    /** Gets a candidate target for this call. */
    cached
    abstract Function resolve();

    /**
     * Whether `src` can flow to this call.
     *
     * Searches backwards from `getSrc()` to `src`. The `allowFromArg`
     * parameter is true when the search is allowed to continue backwards into
     * a parameter; non-recursive callers should pass `_` for `allowFromArg`.
     */
    predicate flowsFrom(DataFlow::Node src, boolean allowFromArg) {
      src = this.getSrc() and allowFromArg = true
      or
      exists(DataFlow::Node other, boolean allowOtherFromArg |
        this.flowsFrom(other, allowOtherFromArg)
      |
        // Call argument
        exists(DataFlowCall call, int i |
          other.(DataFlow::ParameterNode).isParameterOf(call.getStaticCallTarget(), i) and
          src.(ArgumentNode).argumentOf(call, i)
        ) and
        allowOtherFromArg = true and
        allowFromArg = true
        or
        // Call return
        exists(DataFlowCall call, ReturnKind returnKind |
          other = getAnOutNode(call, returnKind) and
          src.(ReturnNode).getKind() = returnKind and
          call.getStaticCallTarget() = src.getEnclosingCallable()
        ) and
        allowFromArg = false
        or
        // Local flow
        DataFlow::localFlowStep(src, other) and
        allowFromArg = allowOtherFromArg
      )
      or
      // Flow through global variable
      exists(StoreInstruction store, Variable var |
        store = src.asInstruction() and
        var = store.getDestinationAddress().(VariableAddressInstruction).getASTVariable() and
        this.flowsFromGlobal(var) and
        allowFromArg = true
      )
    }

    private predicate flowsFromGlobal(GlobalOrNamespaceVariable var) {
      exists(LoadInstruction load |
        this.flowsFrom(DataFlow::instructionNode(load), _) and
        load.getSourceAddress().(VariableAddressInstruction).getASTVariable() = var
      )
    }
  }

  /** Call through a function pointer. */
  private class DataSensitiveExprCall extends DataSensitiveCall {
    DataSensitiveExprCall() { not exists(this.getStaticCallTarget()) }

    override DataFlow::Node getSrc() { result.asInstruction() = this.getCallTarget() }

    override Function resolve() {
      exists(FunctionInstruction fi |
        this.flowsFrom(DataFlow::instructionNode(fi), _) and
        result = fi.getFunctionSymbol()
      )
    }
  }

  /** Call to a virtual function. */
  private class DataSensitiveOverriddenFunctionCall extends DataSensitiveCall {
    DataSensitiveOverriddenFunctionCall() {
      exists(this.getStaticCallTarget().(VirtualFunction).getAnOverridingFunction())
    }

    override DataFlow::Node getSrc() { result.asInstruction() = this.getThisArgument() }

    override MemberFunction resolve() {
      exists(Class overridingClass |
        this.overrideMayAffectCall(overridingClass, result) and
        this.hasFlowFromCastFrom(overridingClass)
      )
    }

    /**
     * Holds if `this` is a virtual function call whose static target is
     * overridden by `overridingFunction` in `overridingClass`.
     */
    pragma[noinline]
    private predicate overrideMayAffectCall(Class overridingClass, MemberFunction overridingFunction) {
      overridingFunction.getAnOverriddenFunction+() = this.getStaticCallTarget().(VirtualFunction) and
      overridingFunction.getDeclaringType() = overridingClass
    }

    /**
     * Holds if the qualifier of `this` has flow from an upcast from
     * `derivedClass`.
     */
    pragma[noinline]
    private predicate hasFlowFromCastFrom(Class derivedClass) {
      exists(ConvertToBaseInstruction toBase |
        this.flowsFrom(DataFlow::instructionNode(toBase), _) and
        derivedClass = toBase.getDerivedClass()
      )
    }
  }
}

/**
 * Holds if `f` is a function with a body that has name `qualifiedName` and
 * `nparams` parameter count. See `functionSignature`.
 */
private predicate functionSignatureWithBody(string qualifiedName, int nparams, Function f) {
  functionSignature(f, qualifiedName, nparams) and
  exists(f.getBlock())
}

/**
 * Holds if the target of `call` is a function _with no definition_ that has
 * name `qualifiedName` and `nparams` parameter count. See `functionSignature`.
 */
pragma[noinline]
private predicate callSignatureWithoutBody(string qualifiedName, int nparams, CallInstruction call) {
  exists(Function target |
    target = call.getStaticCallTarget() and
    not exists(target.getBlock()) and
    functionSignature(target, qualifiedName, nparams)
  )
}

/**
 * Holds if `f` has name `qualifiedName` and `nparams` parameter count. This is
 * an approximation of its signature for the purpose of matching functions that
 * might be the same across link targets.
 */
private predicate functionSignature(Function f, string qualifiedName, int nparams) {
  qualifiedName = f.getQualifiedName() and
  nparams = f.getNumberOfParameters() and
  not f.isStatic()
}

/**
 * Holds if the call context `ctx` reduces the set of viable dispatch
 * targets of `ma` in `c`.
 */
predicate reducedViableImplInCallContext(CallInstruction call, Function f, CallInstruction ctx) {
  none()
}

/**
 * Gets a viable dispatch target of `ma` in the context `ctx`. This is
 * restricted to those `ma`s for which the context makes a difference.
 */
Function prunedViableImplInCallContext(CallInstruction call, CallInstruction ctx) { none() }

/**
 * Holds if flow returning from `m` to `ma` might return further and if
 * this path restricts the set of call sites that can be returned to.
 */
predicate reducedViableImplInReturn(Function f, CallInstruction call) { none() }

/**
 * Gets a viable dispatch target of `ma` in the context `ctx`. This is
 * restricted to those `ma`s and results for which the return flow from the
 * result to `ma` restricts the possible context `ctx`.
 */
Function prunedViableImplInCallContextReverse(CallInstruction call, CallInstruction ctx) { none() }
