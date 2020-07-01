/**
 * Provides implementation classes modelling `memset` and various similar
 * functions. See `semmle.code.cpp.models.Models` for usage information.
 */

import semmle.code.cpp.Function
import semmle.code.cpp.models.interfaces.ArrayFunction
import semmle.code.cpp.models.interfaces.DataFlow
import semmle.code.cpp.models.interfaces.Alias
import semmle.code.cpp.models.interfaces.SideEffect

/**
 * The standard function `memset` and its assorted variants
 */
class MemsetFunction extends ArrayFunction, DataFlowFunction, AliasFunction, SideEffectFunction {
  MemsetFunction() {
    hasGlobalName("memset") or
    hasGlobalName("wmemset") or
    hasGlobalName("bzero") or
    hasGlobalName("__builtin_memset") or
    hasGlobalName("__builtin_memset_chk") or
    hasQualifiedName("std", "memset") or
    hasQualifiedName("std", "wmemset")
  }

  override predicate hasArrayOutput(int bufParam) { bufParam = 0 }

  override predicate hasDataFlow(FunctionInput input, FunctionOutput output) {
    input.isParameter(0) and
    output.isReturnValue()
  }

  override predicate hasArrayWithVariableSize(int bufParam, int countParam) {
    bufParam = 0 and
    (if hasGlobalName("bzero") then countParam = 1 else countParam = 2)
  }

  override predicate parameterNeverEscapes(int index) { hasGlobalName("bzero") and index = 0 }

  override predicate parameterEscapesOnlyViaReturn(int index) {
    not hasGlobalName("bzero") and index = 0
  }

  override predicate parameterIsAlwaysReturned(int index) {
    not hasGlobalName("bzero") and index = 0
  }

  override predicate hasOnlySpecificReadSideEffects() { any() }

  override predicate hasOnlySpecificWriteSideEffects() { any() }

  override predicate hasSpecificWriteSideEffect(ParameterIndex i, boolean buffer, boolean mustWrite) {
    i = 0 and buffer = true and mustWrite = true
  }

  override ParameterIndex getParameterSizeIndex(ParameterIndex i) {
    i = 0 and
    if hasGlobalName("bzero") then result = 1 else result = 2
  }
}
