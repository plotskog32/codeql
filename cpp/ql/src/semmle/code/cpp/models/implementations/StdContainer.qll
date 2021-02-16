/**
 * Provides models for C++ containers `std::array`, `std::vector`, `std::deque`, `std::list` and `std::forward_list`.
 */

import semmle.code.cpp.models.interfaces.Taint
import semmle.code.cpp.models.interfaces.Iterator

/**
 * The `std::array` template class.
 */
private class Array extends Class {
  Array() { this.hasQualifiedName(["std", "bsl"], "array") }
}

/**
 * The `std::deque` template class.
 */
private class Deque extends Class {
  Deque() { this.hasQualifiedName(["std", "bsl"], "deque") }
}

/**
 * The `std::forward_list` template class.
 */
private class ForwardList extends Class {
  ForwardList() { this.hasQualifiedName(["std", "bsl"], "forward_list") }
}

/**
 * The `std::list` template class.
 */
private class List extends Class {
  List() { this.hasQualifiedName(["std", "bsl"], "list") }
}

/**
 * The `std::vector` template class.
 */
private class Vector extends Class {
  Vector() { this.hasQualifiedName(["std", "bsl"], "vector") }
}

/**
 * Additional model for standard container constructors that reference the
 * value type of the container (that is, the `T` in `std::vector<T>`).  For
 * example the fill constructor:
 * ```
 * std::vector<std::string> v(100, potentially_tainted_string);
 * ```
 */
private class StdSequenceContainerConstructor extends Constructor, TaintFunction {
  StdSequenceContainerConstructor() {
    this.getDeclaringType() instanceof Vector or
    this.getDeclaringType() instanceof Deque or
    this.getDeclaringType() instanceof List or
    this.getDeclaringType() instanceof ForwardList
  }

  /**
   * Gets the index of a parameter to this function that is a reference to the
   * value type of the container.
   */
  int getAValueTypeParameterIndex() {
    getParameter(result).getUnspecifiedType().(ReferenceType).getBaseType() =
      getDeclaringType().getTemplateArgument(0).(Type).getUnspecifiedType() // i.e. the `T` of this `std::vector<T>`
  }

  /**
   * Gets the index of a parameter to this function that is an iterator.
   */
  int getAnIteratorParameterIndex() { getParameter(result).getType() instanceof Iterator }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // taint flow from any parameter of the value type to the returned object
    (
      input.isParameterDeref(getAValueTypeParameterIndex()) or
      input.isParameter(getAnIteratorParameterIndex())
    ) and
    (
      output.isReturnValue() // TODO: this is only needed for AST data flow, which treats constructors as returning the new object
      or
      output.isQualifierObject()
    )
  }
}

/**
 * The standard container function `data`.
 */
private class StdSequenceContainerData extends TaintFunction {
  StdSequenceContainerData() {
    this.hasName("data") and
    (
      this.getDeclaringType() instanceof Vector or
      this.getDeclaringType() instanceof Array
    )
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from container itself (qualifier) to return value
    input.isQualifierObject() and
    output.isReturnValueDeref()
    or
    // reverse flow from returned reference to the qualifier (for writes to
    // `data`)
    input.isReturnValueDeref() and
    output.isQualifierObject()
  }
}

/**
 * The standard container functions `push_back` and `push_front`.
 */
private class StdSequenceContainerPush extends TaintFunction {
  StdSequenceContainerPush() {
    this.hasName("push_back") and
    (
      this.getDeclaringType() instanceof Array or
      this.getDeclaringType() instanceof Deque or
      this.getDeclaringType() instanceof List
    )
    or
    this.hasName("push_front") and
    (
      this.getDeclaringType() instanceof Deque or
      this.getDeclaringType() instanceof ForwardList or
      this.getDeclaringType() instanceof List
    )
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from parameter to qualifier
    input.isParameterDeref(0) and
    output.isQualifierObject()
  }
}

/**
 * The standard container functions `front` and `back`.
 */
private class StdSequenceContainerFrontBack extends TaintFunction {
  StdSequenceContainerFrontBack() {
    this.hasName("front") and
    (
      this.getDeclaringType() instanceof Array or
      this.getDeclaringType() instanceof Deque or
      this.getDeclaringType() instanceof ForwardList or
      this.getDeclaringType() instanceof List or
      this.getDeclaringType() instanceof Vector
    )
    or
    this.hasName("back") and
    (
      this.getDeclaringType() instanceof Array or
      this.getDeclaringType() instanceof Deque or
      this.getDeclaringType() instanceof List or
      this.getDeclaringType() instanceof Vector
    )
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from object to returned reference
    input.isQualifierObject() and
    output.isReturnValueDeref()
  }
}

/**
 * The standard container functions `insert` and `insert_after`.
 */
private class StdSequenceContainerInsert extends TaintFunction {
  StdSequenceContainerInsert() {
    this.hasName("insert") and
    (
      this.getDeclaringType() instanceof Deque or
      this.getDeclaringType() instanceof List or
      this.getDeclaringType() instanceof Vector
    )
    or
    this.hasName("insert_after") and
    this.getDeclaringType() instanceof ForwardList
  }

  /**
   * Gets the index of a parameter to this function that is a reference to the
   * value type of the container.
   */
  int getAValueTypeParameterIndex() {
    getParameter(result).getUnspecifiedType().(ReferenceType).getBaseType() =
      getDeclaringType().getTemplateArgument(0).(Type).getUnspecifiedType() // i.e. the `T` of this `std::vector<T>`
  }

  /**
   * Gets the index of a parameter to this function that is an iterator.
   */
  int getAnIteratorParameterIndex() { getParameter(result).getType() instanceof Iterator }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from parameter to container itself (qualifier) and return value
    (
      input.isQualifierObject() or
      input.isParameterDeref(getAValueTypeParameterIndex()) or
      input.isParameter(getAnIteratorParameterIndex())
    ) and
    (
      output.isQualifierObject() or
      output.isReturnValueDeref()
    )
  }
}

/**
 * The standard container function `assign`.
 */
private class StdSequenceContainerAssign extends TaintFunction {
  StdSequenceContainerAssign() {
    this.hasName("assign") and
    (
      this.getDeclaringType() instanceof Deque or
      this.getDeclaringType() instanceof ForwardList or
      this.getDeclaringType() instanceof List or
      this.getDeclaringType() instanceof Vector
    )
  }

  /**
   * Gets the index of a parameter to this function that is a reference to the
   * value type of the container.
   */
  int getAValueTypeParameterIndex() {
    getParameter(result).getUnspecifiedType().(ReferenceType).getBaseType() =
      getDeclaringType().getTemplateArgument(0).(Type).getUnspecifiedType() // i.e. the `T` of this `std::vector<T>`
  }

  /**
   * Gets the index of a parameter to this function that is an iterator.
   */
  int getAnIteratorParameterIndex() { getParameter(result).getType() instanceof Iterator }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from parameter to container itself (qualifier)
    (
      input.isParameterDeref(getAValueTypeParameterIndex()) or
      input.isParameter(getAnIteratorParameterIndex())
    ) and
    output.isQualifierObject()
  }
}

/**
 * The standard container functions `at` and `operator[]`.
 */
private class StdSequenceContainerAt extends TaintFunction {
  StdSequenceContainerAt() {
    this.hasName(["at", "operator[]"]) and
    (
      this.getDeclaringType() instanceof Array or
      this.getDeclaringType() instanceof Deque or
      this.getDeclaringType() instanceof Vector
    )
  }

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
 * The standard vector `emplace` function.
 */
class StdVectorEmplace extends TaintFunction {
  StdVectorEmplace() {
    this.hasName("emplace") and
    this.getDeclaringType() instanceof Vector
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from any parameter except the position iterator to qualifier and return value
    // (here we assume taint flow from any constructor parameter to the constructed object)
    input.isParameterDeref([1 .. getNumberOfParameters() - 1]) and
    (
      output.isQualifierObject() or
      output.isReturnValue()
    )
  }
}

/**
 * The standard vector `emplace_back` function.
 */
class StdVectorEmplaceBack extends TaintFunction {
  StdVectorEmplaceBack() {
    this.hasName("emplace_back") and
    this.getDeclaringType() instanceof Vector
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from any parameter to qualifier
    // (here we assume taint flow from any constructor parameter to the constructed object)
    input.isParameterDeref([0 .. getNumberOfParameters() - 1]) and
    output.isQualifierObject()
  }
}
