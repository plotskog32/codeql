/**
 * Provides models for C++ containers `std::map` and `std::unordered_map`.
 */

import semmle.code.cpp.models.interfaces.Taint
import semmle.code.cpp.models.implementations.Iterator

/**
 * Additional model for map constructors using iterator inputs.
 */
class StdMapConstructor extends Constructor, TaintFunction {
  StdMapConstructor() {
    this.hasQualifiedName("std", "map", "map") or
    this.hasQualifiedName("std", "unordered_map", "unordered_map")
  }

  /**
   * Gets the index of a parameter to this function that is an iterator.
   */
  int getAnIteratorParameterIndex() {
    getParameter(result).getUnspecifiedType() instanceof Iterator
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // taint flow from any parameter of an iterator type to the qualifier
    input.isParameterDeref(getAnIteratorParameterIndex()) and
    (
      output.isReturnValue() // TODO: this is only needed for AST data flow, which treats constructors as returning the new object
      or
      output.isQualifierObject()
    )
  }
}

/**
 * The standard map `insert` and `insert_or_assign` functions.
 */
class StdMapInsert extends TaintFunction {
  StdMapInsert() {
    this.hasQualifiedName("std", ["map", "unordered_map"], ["insert", "insert_or_assign"])
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from last parameter to qualifier and return value
    // (where the return value is a pair, this should really flow just to the first part of it)
    input.isParameterDeref(getNumberOfParameters() - 1) and
    (
      output.isQualifierObject() or
      output.isReturnValue()
    )
  }
}

/**
 * The standard map `swap` functions.
 */
class StdMapSwap extends TaintFunction {
  StdMapSwap() { this.hasQualifiedName("std", ["map", "unordered_map"], "swap") }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // container1.swap(container2)
    input.isQualifierObject() and
    output.isParameterDeref(0)
    or
    input.isParameterDeref(0) and
    output.isQualifierObject()
  }
}

/**
 * The standard map functions `at` and `operator[]`.
 */
class StdMapAt extends TaintFunction {
  StdMapAt() { this.hasQualifiedName("std", ["map", "unordered_map"], ["at", "operator[]"]) }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from qualifier to referenced return value
    input.isQualifierObject() and
    output.isReturnValueDeref()
    or
    // reverse flow from returned reference to the qualifier
    input.isReturnValueDeref() and
    output.isQualifierObject()
  }
}

/**
 * The standard map `find` function.
 */
class StdMapFind extends TaintFunction {
  StdMapFind() { this.hasQualifiedName("std", ["map", "unordered_map"], "find") }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    input.isQualifierObject() and
    output.isReturnValue()
  }
}

/**
 * The standard map `erase` function.
 */
class StdMapErase extends TaintFunction {
  StdMapErase() { this.hasQualifiedName("std", ["map", "unordered_map"], "erase") }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from qualifier to iterator return value
    getType().getUnderlyingType() instanceof Iterator and
    input.isQualifierObject() and
    output.isReturnValue()
  }
}
