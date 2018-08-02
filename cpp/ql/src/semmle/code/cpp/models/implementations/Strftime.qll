import semmle.code.cpp.models.interfaces.Taint
import semmle.code.cpp.models.interfaces.ArrayFunction

class Strftime extends TaintFunction, ArrayFunction {
  Strftime() {
    hasQualifiedName("strftime")
  }
  
  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    (
      input.isInParameter(1) or
      input.isInParameterPointer(2) or
      input.isInParameterPointer(3)
    )
    and
    (
      output.isOutParameterPointer(0) or
      output.isOutReturnValue()
    )
  }
  
  override predicate hasArrayWithNullTerminator(int bufParam) {
    bufParam = 2
  }
  
  override predicate hasArrayWithFixedSize(int bufParam, int elemCount) {
    bufParam = 3 and
    elemCount = 1
  }
  
  override predicate hasArrayWithVariableSize(int bufParam, int countParam) {
    bufParam = 0 and
    countParam = 1
  }
  
  override predicate hasArrayInput(int bufParam) {
    bufParam = 2 or
    bufParam = 3
  }
  
  override predicate hasArrayOutput(int bufParam) {
    bufParam = 0
  }
}
