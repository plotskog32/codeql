import semmle.code.cpp.models.interfaces.Taint

class UniqueOrSharedPtr extends Class {
  UniqueOrSharedPtr() { this.hasQualifiedName("std", ["shared_ptr", "unique_ptr"]) }
}

class MakeUniqueOrShared extends TaintFunction {
  MakeUniqueOrShared() { this.hasQualifiedName("std", ["make_shared", "make_unique"]) }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    // Exclude the `template<class T> shared_ptr<T[]> make_shared(std::size_t)` specialization
    // since we don't want to propagate taint via the size of the allocation.
    not this.isArray() and
    input.isParameter(_) and
    output.isReturnValue()
  }

  /**
   * Holds if the function returns a `shared_ptr<T>` (or `unique_ptr<T>`) where `T` is an
   * array type (i.e., `U[]` for some type `U`).
   */
  predicate isArray() {
    this.getTemplateArgument(0).(Type).getUnderlyingType() instanceof ArrayType
  }
}

/**
 * A prefix `operator*` member function for a `shared_ptr` or `unique_ptr` type.
 */
class UniqueOrSharedDereferenceMemberOperator extends MemberFunction, TaintFunction {
  UniqueOrSharedDereferenceMemberOperator() {
    this.hasName("operator*") and
    this.getDeclaringType() instanceof UniqueOrSharedPtr
  }

  override predicate hasTaintFlow(FunctionInput input, FunctionOutput output) {
    input.isQualifierObject() and
    output.isReturnValueDeref()
  }
}
