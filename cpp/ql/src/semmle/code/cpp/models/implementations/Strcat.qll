/**
 * Provides implementation classes modeling `strcat` and various similar functions.
 * See `semmle.code.cpp.models.Models` for usage information.
 */

import semmle.code.cpp.models.interfaces.ArrayFunction
import semmle.code.cpp.models.interfaces.DataFlow
import semmle.code.cpp.models.interfaces.Taint
import semmle.code.cpp.models.interfaces.SideEffect

/**
 * The standard function `strcat` and its wide, sized, and Microsoft variants.
 */
class StrcatFunction extends TaintFunction, DataFlowFunction, ArrayFunction, SideEffectFunction {
  StrcatFunction() {
    getName() =
      [
        "strcat", // strcat(dst, src)
        "strncat", // strncat(dst, src, max_amount)
        "wcscat", // wcscat(dst, src)
        "_mbscat", // _mbscat(dst, src)
        "wcsncat", // wcsncat(dst, src, max_amount)
        "_mbsncat", // _mbsncat(dst, src, max_amount)
        "_mbsncat_l" // _mbsncat_l(dst, src, max_amount, locale)
      ]
  }

  /**
   * Gets the index of the parameter that is the size of the copy (in characters).
   */
  int getParamSize() { exists(getParameter(2)) and result = 2 }

  /**
   * Gets the index of the parameter that is the source of the copy.
   */
  int getParamSrc() { result = 1 }

  /**
   * Gets the index of the parameter that is the destination to be appended to.
   */
  int getParamDest() { result = 0 }

  override predicate hasDataFlow(FunctionInput input, FunctionOutput output) {
    input.isParameter(0) and
    output.isReturnValue()
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    getName() = ["strncat", "wcsncat", "_mbsncat", "_mbsncat_l"] and
    input.isParameter(2) and
    output.isParameterDeref(0)
    or
    getName() = "_mbsncat_l" and
    input.isParameter(3) and
    output.isParameterDeref(0)
    or
    input.isParameterDeref(0) and
    output.isParameterDeref(0)
    or
    input.isParameter(1) and
    output.isParameterDeref(0)
  }

  override predicate hasArrayInput(int param) {
    param = 0 or
    param = 1
  }

  override predicate hasArrayOutput(int param) { param = 0 }

  override predicate hasArrayWithNullTerminator(int param) { param = 1 }

  override predicate hasArrayWithUnknownSize(int param) { param = 0 }

  override predicate hasOnlySpecificReadSideEffects() { any() }

  override predicate hasOnlySpecificWriteSideEffects() { any() }

  override predicate hasSpecificWriteSideEffect(ParameterIndex i, boolean buffer, boolean mustWrite) {
    i = 0 and
    buffer = true and
    mustWrite = false
  }

  override predicate hasSpecificReadSideEffect(ParameterIndex i, boolean buffer) {
    (i = 0 or i = 1) and
    buffer = true
  }
}
