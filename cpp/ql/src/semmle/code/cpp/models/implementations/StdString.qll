/**
 * Provides implementation classes modeling `std::string` (and other
 * instantiations of `std::basic_string`) and `std::ostream`. See
 * `semmle.code.cpp.models.Models` for usage information.
 */

import semmle.code.cpp.models.interfaces.Taint
import semmle.code.cpp.models.interfaces.Iterator
import semmle.code.cpp.models.interfaces.DataFlow

/**
 * The `std::basic_string` template class instantiations.
 */
private class StdBasicString extends ClassTemplateInstantiation {
  StdBasicString() { this.getTemplate().hasQualifiedName("std", "basic_string") }
}

/**
 * Additional model for `std::string` constructors that reference the character
 * type of the container, or an iterator.  For example construction from
 * iterators:
 * ```
 * std::string b(a.begin(), a.end());
 * ```
 */
private class StdStringConstructor extends Constructor, TaintFunction {
  StdStringConstructor() { this.getDeclaringType() instanceof StdBasicString }

  /**
   * Gets the index of a parameter to this function that is a string (or
   * character).
   */
  int getAStringParameterIndex() {
    exists(Type paramType | paramType = getParameter(result).getUnspecifiedType() |
      // e.g. `std::basic_string::CharT *`
      paramType instanceof PointerType
      or
      // e.g. `std::basic_string &`, avoiding `const Allocator&`
      paramType instanceof ReferenceType and
      not paramType.(ReferenceType).getBaseType() =
        getDeclaringType().getTemplateArgument(2).(Type).getUnspecifiedType()
      or
      // i.e. `std::basic_string::CharT`
      getParameter(result).getUnspecifiedType() =
        getDeclaringType().getTemplateArgument(0).(Type).getUnspecifiedType()
    )
  }

  /**
   * Gets the index of a parameter to this function that is an iterator.
   */
  int getAnIteratorParameterIndex() { getParameter(result).getType() instanceof Iterator }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // taint flow from any parameter of the value type to the returned object
    (
      input.isParameterDeref(getAStringParameterIndex()) or
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
 * The `std::string` function `c_str`.
 */
private class StdStringCStr extends TaintFunction {
  StdStringCStr() { this.getDeclaringType() instanceof StdBasicString and this.hasName("c_str") }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from string itself (qualifier) to return value
    input.isQualifierObject() and
    output.isReturnValueDeref()
  }
}

/**
 * The `std::string` function `data`.
 */
private class StdStringData extends TaintFunction {
  StdStringData() { this.getDeclaringType() instanceof StdBasicString and this.hasName("data") }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from string itself (qualifier) to return value
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
 * The `std::string` function `push_back`.
 */
private class StdStringPush extends TaintFunction {
  StdStringPush() {
    this.getDeclaringType().(ClassTemplateInstantiation) instanceof StdBasicString and
    this.hasName("push_back")
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from parameter to qualifier
    input.isParameterDeref(0) and
    output.isQualifierObject()
  }
}

/**
 * The `std::string` functions `front` and `back`.
 */
private class StdStringFrontBack extends TaintFunction {
  StdStringFrontBack() {
    this.getDeclaringType() instanceof StdBasicString and this.hasName(["front", "back"])
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from object to returned reference
    input.isQualifierObject() and
    output.isReturnValueDeref()
  }
}

/**
 * The (non-member) `std::string` function `operator+`.
 */
private class StdStringPlus extends TaintFunction {
  StdStringPlus() {
    this.hasQualifiedName("std", "operator+") and
    this.getUnspecifiedType() instanceof StdBasicString
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from parameters to return value
    (
      input.isParameterDeref(0) or
      input.isParameterDeref(1)
    ) and
    output.isReturnValue()
  }
}

/**
 * The `std::string` functions `operator+=`, `append`, `insert` and
 * `replace`. All of these functions combine the existing string
 * with a new string (or character) from one of the arguments.
 */
private class StdStringAppend extends TaintFunction {
  StdStringAppend() {
    this.getDeclaringType() instanceof StdBasicString and
    this.hasName(["operator+=", "append", "insert", "replace"])
  }

  /**
   * Gets the index of a parameter to this function that is a string (or
   * character).
   */
  int getAStringParameterIndex() {
    getParameter(result).getType() instanceof PointerType or // e.g. `std::basic_string::CharT *`
    getParameter(result).getType() instanceof ReferenceType or // e.g. `std::basic_string &`
    getParameter(result).getUnspecifiedType() =
      getDeclaringType().getTemplateArgument(0).(Type).getUnspecifiedType() // i.e. `std::basic_string::CharT`
  }

  /**
   * Gets the index of a parameter to this function that is an iterator.
   */
  int getAnIteratorParameterIndex() { getParameter(result).getType() instanceof Iterator }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from string and parameter to string (qualifier) and return value
    (
      input.isQualifierObject() or
      input.isParameterDeref(getAStringParameterIndex()) or
      input.isParameter(getAnIteratorParameterIndex())
    ) and
    (
      output.isQualifierObject() or
      output.isReturnValueDeref()
    )
    or
    // reverse flow from returned reference to the qualifier (for writes to
    // the result)
    input.isReturnValueDeref() and
    output.isQualifierObject()
  }
}

/**
 * The standard function `std::string.assign`.
 */
private class StdStringAssign extends TaintFunction {
  StdStringAssign() { this.getDeclaringType() instanceof StdBasicString and this.hasName("assign") }

  /**
   * Gets the index of a parameter to this function that is a string (or
   * character).
   */
  int getAStringParameterIndex() {
    getParameter(result).getType() instanceof PointerType or // e.g. `std::basic_string::CharT *`
    getParameter(result).getType() instanceof ReferenceType or // e.g. `std::basic_string &`
    getParameter(result).getUnspecifiedType() =
      getDeclaringType().getTemplateArgument(0).(Type).getUnspecifiedType() // i.e. `std::basic_string::CharT`
  }

  /**
   * Gets the index of a parameter to this function that is an iterator.
   */
  int getAnIteratorParameterIndex() { getParameter(result).getType() instanceof Iterator }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from parameter to string itself (qualifier) and return value
    (
      input.isParameterDeref(getAStringParameterIndex()) or
      input.isParameter(getAnIteratorParameterIndex())
    ) and
    (
      output.isQualifierObject() or
      output.isReturnValueDeref()
    )
    or
    // reverse flow from returned reference to the qualifier (for writes to
    // the result)
    input.isReturnValueDeref() and
    output.isQualifierObject()
  }
}

/**
 * The standard function `std::string.copy`.
 */
private class StdStringCopy extends TaintFunction {
  StdStringCopy() { this.getDeclaringType() instanceof StdBasicString and this.hasName("copy") }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // copy(dest, num, pos)
    input.isQualifierObject() and
    output.isParameterDeref(0)
  }
}

/**
 * The standard function `std::string.substr`.
 */
private class StdStringSubstr extends TaintFunction {
  StdStringSubstr() { this.getDeclaringType() instanceof StdBasicString and this.hasName("substr") }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // substr(pos, num)
    input.isQualifierObject() and
    output.isReturnValue()
  }
}

/**
 * The `std::basic_stringstream` template class instantiations.
 */
private class StdBasicStringStream extends ClassTemplateInstantiation {
  StdBasicStringStream() { this.getTemplate().hasQualifiedName("std", "basic_stringstream") }
}

/**
 * The `std::string` functions `at` and `operator[]`.
 */
private class StdStringAt extends TaintFunction {
  StdStringAt() {
    this.getDeclaringType() instanceof StdBasicString and this.hasName(["at", "operator[]"])
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
 * The `std::basic_istream` template class instantiations.
 */
private class StdBasicIStream extends ClassTemplateInstantiation {
  StdBasicIStream() { this.getTemplate().hasQualifiedName("std", "basic_istream") }
}

/**
 * The `std::istream` function `operator>>` (defined as a member function).
 */
private class StdIStreamIn extends DataFlowFunction, TaintFunction {
  StdIStreamIn() {
    this.getDeclaringType() instanceof StdBasicIStream and this.hasName("operator>>")
  }

  override predicate hasDataFlow(FunctionInput input, FunctionOutput output) {
    // returns reference to `*this`
    input.isQualifierAddress() and
    output.isReturnValue()
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from qualifier to first parameter
    input.isQualifierObject() and
    output.isParameterDeref(0)
    or
    // reverse flow from returned reference to the qualifier
    input.isReturnValueDeref() and
    output.isQualifierObject()
  }
}

/**
 * The `std::istream` function `operator>>` (defined as a non-member function).
 */
private class StdIStreamInNonMember extends DataFlowFunction, TaintFunction {
  StdIStreamInNonMember() {
    this.hasQualifiedName("std", "operator>>") and
    this.getUnspecifiedType().(ReferenceType).getBaseType() instanceof StdBasicIStream
  }

  override predicate hasDataFlow(FunctionInput input, FunctionOutput output) {
    // flow from first parameter to return value
    input.isParameter(0) and
    output.isReturnValue()
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from first parameter to second parameter
    input.isParameterDeref(0) and
    output.isParameterDeref(1)
    or
    // reverse flow from returned reference to the first parameter
    input.isReturnValueDeref() and
    output.isParameterDeref(0)
  }
}

/**
 * The `std::istream` functions `get` (without parameters) and `peek`.
 */
private class StdIStreamGet extends TaintFunction {
  StdIStreamGet() {
    this.getDeclaringType() instanceof StdBasicIStream and
    this.hasName(["get", "peek"]) and
    this.getNumberOfParameters() = 0
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from qualifier to return value
    input.isQualifierObject() and
    output.isReturnValue()
  }
}

/**
 * The `std::istream` functions `get` (with parameters) and `read`.
 */
private class StdIStreamRead extends DataFlowFunction, TaintFunction {
  StdIStreamRead() {
    this.getDeclaringType() instanceof StdBasicIStream and
    this.hasName(["get", "read"]) and
    this.getNumberOfParameters() > 0
  }

  override predicate hasDataFlow(FunctionInput input, FunctionOutput output) {
    // returns reference to `*this`
    input.isQualifierAddress() and
    output.isReturnValue()
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from qualifier to first parameter
    input.isQualifierObject() and
    output.isParameterDeref(0)
    or
    // reverse flow from returned reference to the qualifier
    input.isReturnValueDeref() and
    output.isQualifierObject()
  }
}

/**
 * The `std::istream` function `readsome`.
 */
private class StdIStreamReadSome extends TaintFunction {
  StdIStreamReadSome() {
    this.getDeclaringType() instanceof StdBasicIStream and this.hasName("readsome")
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from qualifier to first parameter
    input.isQualifierObject() and
    output.isParameterDeref(0)
  }
}

/**
 * The `std::istream` function `putback`.
 */
private class StdIStreamPutBack extends DataFlowFunction, TaintFunction {
  StdIStreamPutBack() {
    this.getDeclaringType() instanceof StdBasicIStream and this.hasName("putback")
  }

  override predicate hasDataFlow(FunctionInput input, FunctionOutput output) {
    // returns reference to `*this`
    input.isQualifierAddress() and
    output.isReturnValue()
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from first parameter (value or pointer) to qualifier
    input.isParameter(0) and
    output.isQualifierObject()
    or
    input.isParameterDeref(0) and
    output.isQualifierObject()
    or
    // flow from first parameter (value or pointer) to return value
    input.isParameter(0) and
    output.isReturnValueDeref()
    or
    input.isParameterDeref(0) and
    output.isReturnValueDeref()
    or
    // reverse flow from returned reference to the qualifier
    input.isReturnValueDeref() and
    output.isQualifierObject()
  }
}

/**
 * The `std::istream` function `getline`.
 */
private class StdIStreamGetLine extends DataFlowFunction, TaintFunction {
  StdIStreamGetLine() {
    this.getDeclaringType() instanceof StdBasicIStream and this.hasName("getline")
  }

  override predicate hasDataFlow(FunctionInput input, FunctionOutput output) {
    // returns reference to `*this`
    input.isQualifierAddress() and
    output.isReturnValue()
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from qualifier to first parameter
    input.isQualifierObject() and
    output.isParameterDeref(0)
    or
    // reverse flow from returned reference to the qualifier
    input.isReturnValueDeref() and
    output.isQualifierObject()
  }
}

/**
 * The (non-member) function `std::getline`.
 */
private class StdGetLine extends DataFlowFunction, TaintFunction {
  StdGetLine() { this.hasQualifiedName("std", "getline") }

  override predicate hasDataFlow(FunctionInput input, FunctionOutput output) {
    // flow from first parameter to return value
    input.isParameter(0) and
    output.isReturnValue()
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from first parameter to second parameter
    input.isParameterDeref(0) and
    output.isParameterDeref(1)
    or
    // reverse flow from returned reference to first parameter
    input.isReturnValueDeref() and
    output.isParameterDeref(0)
  }
}

/**
 * The `std::basic_ostream` template class instantiations.
 */
private class StdBasicOStream extends ClassTemplateInstantiation {
  StdBasicOStream() { this.getTemplate().hasQualifiedName("std", "basic_ostream") }
}

/**
 * The `std::ostream` functions `operator<<` (defined as a member function),
 * `put` and `write`.
 */
private class StdOStreamOut extends DataFlowFunction, TaintFunction {
  StdOStreamOut() {
    this.getDeclaringType() instanceof StdBasicOStream and
    this.hasName(["operator<<", "put", "write"])
  }

  override predicate hasDataFlow(FunctionInput input, FunctionOutput output) {
    // returns reference to `*this`
    input.isQualifierAddress() and
    output.isReturnValue()
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from first parameter (value or pointer) to qualifier
    input.isParameter(0) and
    output.isQualifierObject()
    or
    input.isParameterDeref(0) and
    output.isQualifierObject()
    or
    // flow from first parameter (value or pointer) to return value
    input.isParameter(0) and
    output.isReturnValueDeref()
    or
    input.isParameterDeref(0) and
    output.isReturnValueDeref()
    or
    // reverse flow from returned reference to the qualifier
    input.isReturnValueDeref() and
    output.isQualifierObject()
  }
}

/**
 * The `std::ostream` function `operator<<` (defined as a non-member function).
 */
private class StdOStreamOutNonMember extends DataFlowFunction, TaintFunction {
  StdOStreamOutNonMember() {
    this.hasQualifiedName("std", "operator<<") and
    this.getUnspecifiedType().(ReferenceType).getBaseType() instanceof StdBasicOStream
  }

  override predicate hasDataFlow(FunctionInput input, FunctionOutput output) {
    // flow from first parameter to return value
    input.isParameter(0) and
    output.isReturnValue()
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from second parameter to first parameter
    input.isParameter(1) and
    output.isParameterDeref(0)
    or
    // flow from second parameter to return value
    input.isParameter(1) and
    output.isReturnValueDeref()
    or
    // reverse flow from returned reference to the first parameter
    input.isReturnValueDeref() and
    output.isParameterDeref(0)
  }
}

/**
 * Additional model for `std::stringstream` constructors that take a string
 * input parameter.
 */
private class StdStringStreamConstructor extends Constructor, TaintFunction {
  StdStringStreamConstructor() { this.getDeclaringType() instanceof StdBasicStringStream }

  /**
   * Gets the index of a parameter to this function that is a string.
   */
  int getAStringParameterIndex() {
    getParameter(result).getType() instanceof ReferenceType // `const std::basic_string &`
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // taint flow from any parameter of string type to the returned object
    input.isParameterDeref(getAStringParameterIndex()) and
    (
      output.isReturnValue() // TODO: this is only needed for AST data flow, which treats constructors as returning the new object
      or
      output.isQualifierObject()
    )
  }
}

/**
 * The `std::stringstream` function `str`.
 */
private class StdStringStreamStr extends TaintFunction {
  StdStringStreamStr() {
    this.getDeclaringType() instanceof StdBasicStringStream and this.hasName("str")
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // flow from qualifier to return value (if any)
    input.isQualifierObject() and
    output.isReturnValue()
    or
    // flow from first parameter (if any) to qualifier
    input.isParameterDeref(0) and
    output.isQualifierObject()
  }
}

/**
 * The `std::basic_ios` template class instantiations.
 */
private class StdBasicIOS extends ClassTemplateInstantiation {
  StdBasicIOS() { this.getTemplate().hasQualifiedName("std", "basic_ios") }
}

/**
 * A `std::` stream function that does not require a model, except that it
 * returns a reference to `*this` and thus could be used in a chain.
 */
private class StdStreamFunction extends DataFlowFunction, TaintFunction {
  StdStreamFunction() {
    this.getDeclaringType() instanceof StdBasicIStream and
    this.hasName(["ignore", "unget", "seekg"])
    or
    this.getDeclaringType() instanceof StdBasicOStream and this.hasName(["seekp", "flush"])
    or
    this.getDeclaringType() instanceof StdBasicIOS and this.hasName("copyfmt")
  }

  override predicate hasDataFlow(FunctionInput input, FunctionOutput output) {
    // returns reference to `*this`
    input.isQualifierAddress() and
    output.isReturnValue()
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // reverse flow from returned reference to the qualifier
    input.isReturnValueDeref() and
    output.isQualifierObject()
  }
}
