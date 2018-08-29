/**
 * Provides an implementation of Hash consing.
 * See https://en.wikipedia.org/wiki/Hash_consing
 *
 * The predicate `hashCons` converts an expression into a `HashCons`, which is an
 * abstract type presenting the hash-cons of the expression. If two
 * expressions have the same `HashCons` then they are structurally equal.
 *
 * Important note: this library ignores the possibility that the value of
 * an expression might change between one occurrence and the next. For
 * example:
 *
 * ```
 * x = a+b;
 * a++;
 * y = a+b;
 * ```
 *
 * In this example, both copies of the expression `a+b` will hash-cons to
 * the same value, even though the value of `a` has changed. This is the
 * intended behavior of this library. If you care about the value of the
 * expression being the same, then you should use the GlobalValueNumbering
 * library instead.
 *
 * To determine if the expression `x` is structurally equal to the
 * expression `y`, use the library like this:
 *
 * ```
 * hashCons(x) = hashCons(y)
 * ```
 */

/*
 * Note to developers: the correctness of this module depends on the
 * definitions of HC, hashCons, and analyzableExpr being kept in sync with
 * each other. If you change this module then make sure that the change is
 * symmetric across all three.
 */

import cpp

/** Used to represent the hash-cons of an expression. */
private cached newtype HCBase =
  HC_IntLiteral(int val, Type t) { mk_IntLiteral(val,t,_) }
  or
  HC_EnumConstantAccess(EnumConstant val, Type t) { mk_EnumConstantAccess(val,t,_) }
  or
  HC_FloatLiteral(float val, Type t) { mk_FloatLiteral(val,t,_) }
  or
  HC_StringLiteral(string val, Type t) {mk_StringLiteral(val,t,_)}
  or
  HC_Nullptr() {mk_Nullptr(_)}
  or
  HC_Variable(Variable x) {
     mk_Variable(x, _)
  }
  or
  HC_FieldAccess(HashCons s, Field f) {
    mk_DotFieldAccess(s,f,_) or
    mk_PointerFieldAccess_with_deref(s,f,_) or
    mk_ImplicitThisFieldAccess_with_deref(s,f,_)
  }
  or
  HC_Deref(HashCons p) {
    mk_Deref(p,_) or
    mk_PointerFieldAccess(p,_,_) or
    mk_ImplicitThisFieldAccess_with_qualifier(p,_,_)
  }
  or
  HC_ThisExpr(Function fcn) {
    mk_ThisExpr(fcn,_) or
    mk_ImplicitThisFieldAccess(fcn,_,_)
  }
  or
  HC_Conversion(Type t, HashCons child) { mk_Conversion(t, child, _) }
  or
  HC_BinaryOp(HashCons lhs, HashCons rhs, string opname) {
    mk_BinaryOp(lhs, rhs, opname, _)
  }
  or
  HC_UnaryOp(HashCons child, string opname) { mk_UnaryOp(child, opname, _) }
  or
  HC_ArrayAccess(HashCons x, HashCons i) {
    mk_ArrayAccess(x,i,_)
  }
  or
  HC_NonmemberFunctionCall(Function fcn, HC_Args args) {
    mk_NonmemberFunctionCall(fcn, args, _)
  }
  or
  HC_MemberFunctionCall(Function trg, HashCons qual, HC_Args args) {
    mk_MemberFunctionCall(trg, qual, args, _)
  }
  or
  HC_NewExpr(Type t, HC_Alloc alloc, HC_Init init, HC_Align align) {
    mk_NewExpr(t, alloc, init, align, _, _)
  }  or
  HC_NewArrayExpr(Type t, HC_Alloc alloc, HC_Init init, HC_Align align) {
    mk_NewArrayExpr(t, alloc, init, align, _, _)
  }
  or
  HC_SizeofType(Type t) {mk_SizeofType(t, _)}
  or
  HC_SizeofExpr(HashCons child) {mk_SizeofExpr(child, _)}
  or
  HC_AlignofType(Type t) {mk_AlignofType(t, _)}
  or
  HC_AlignofExpr(HashCons child) {mk_AlignofExpr(child, _)}
  or
  HC_ClassAggregateLiteral(Class c, HC_Fields hcf) {
    mk_ClassAggregateLiteral(c, hcf, _)
  }
  or
  HC_ArrayAggregateLiteral(Type t, HC_Array hca) {
    mk_ArrayAggregateLiteral(t, hca, _)
  }
  or
  HC_DeleteExpr(HashCons child) {mk_DeleteExpr(child, _)}
  or
  HC_DeleteArrayExpr(HashCons child) {mk_DeleteArrayExpr(child, _)}
  or
  HC_ThrowExpr(HashCons child) {mk_ThrowExpr(child, _)}
  or
  HC_ReThrowExpr()
  or
  // Any expression that is not handled by the cases above is
  // given a unique number based on the expression itself.
  HC_Unanalyzable(Expr e) { not analyzableExpr(e,_) }

/** Used to implement hash-consing of `new` placement argument lists  */
private newtype HC_Alloc =
  HC_EmptyAllocArgs(Function fcn) {
    exists(NewOrNewArrayExpr n |
      n.getAllocator() = fcn
    ) 
  }
  or HC_AllocArgCons(Function fcn, HashCons hc, int i, HC_Alloc list, boolean aligned) {
    mk_AllocArgCons(fcn, hc, i, list, aligned, _)
  }
  or
  HC_NoAlloc()

/** Used to implement optional init on `new` expressions */
private newtype HC_Init =
  HC_NoInit()
  or
  HC_HasInit(HashCons hc) {mk_HasInit(hc, _)}

private newtype HC_Align = 
  HC_NoAlign()
  or
  HC_HasAlign(HashCons hc) {mk_HasAlign(hc, _)}

/** Used to implement hash-consing of argument lists  */
private newtype HC_Args =
  HC_EmptyArgs(Function fcn) {
    any()
  }
  or HC_ArgCons(Function fcn, HashCons hc, int i, HC_Args list) {
    mk_ArgCons(fcn, hc, i, list, _)
  }

/**
 * Used to implement hash-consing of struct initizializers.
 */
private newtype HC_Fields =
  HC_EmptyFields(Class c) {
    exists(ClassAggregateLiteral cal |
      c = cal.getType().getUnspecifiedType()
    )
  }
  or
  HC_FieldCons(Class c, int i, Field f, HashCons hc, HC_Fields hcf) {
   mk_FieldCons(c, i, f, hc, hcf, _)
  }

private newtype HC_Array =
  HC_EmptyArray(Type t) {
    exists(ArrayAggregateLiteral aal |
      aal.getType() = t
    )
  }
  or
  HC_ArrayCons(Type t, int i, HashCons hc, HC_Array hca) {
    mk_ArrayCons(t, i, hc, hca, _)
  }
/**
 * HashCons is the hash-cons of an expression. The relationship between `Expr`
 * and `HC` is many-to-one: every `Expr` has exactly one `HC`, but multiple
 * expressions can have the same `HC`. If two expressions have the same
 * `HC`, it means that they are structurally equal. The `HC` is an opaque
 * value. The only use for the `HC` of an expression is to find other
 * expressions that are structurally equal to it. Use the predicate
 * `hashCons` to get the `HC` for an `Expr`.
 *
 * Note: `HC` has `toString` and `getLocation` methods, so that it can be
 * displayed in a results list. These work by picking an arbitrary
 * expression with this `HC` and using its `toString` and `getLocation`
 * methods.
 */
class HashCons extends HCBase {
  /** Gets an expression that has this HC. */
  Expr getAnExpr() {
    this = hashCons(result)
  }

  /** Gets the kind of the HC. This can be useful for debugging. */
  string getKind() {
    if this instanceof HC_IntLiteral then result = "IntLiteral" else
    if this instanceof HC_EnumConstantAccess then result = "EnumConstantAccess" else
    if this instanceof HC_FloatLiteral then result = "FloatLiteral" else
    if this instanceof HC_StringLiteral then result = "StringLiteral" else
    if this instanceof HC_Nullptr then result = "Nullptr" else 
    if this instanceof HC_Variable then result = "Variable" else
    if this instanceof HC_FieldAccess then result = "FieldAccess" else
    if this instanceof HC_Deref then result = "Deref" else
    if this instanceof HC_ThisExpr then result = "ThisExpr" else
    if this instanceof HC_Conversion then result = "Conversion" else
    if this instanceof HC_BinaryOp then result = "BinaryOp" else
    if this instanceof HC_UnaryOp then result = "UnaryOp" else
    if this instanceof HC_ArrayAccess then result = "ArrayAccess" else
    if this instanceof HC_Unanalyzable then result = "Unanalyzable" else
    if this instanceof HC_NonmemberFunctionCall then result = "NonmemberFunctionCall" else
    if this instanceof HC_MemberFunctionCall then result = "MemberFunctionCall" else
    if this instanceof HC_NewExpr then result = "NewExpr" else
    if this instanceof HC_NewArrayExpr then result = "NewArrayExpr" else
    if this instanceof HC_SizeofType then result = "SizeofTypeOperator" else
    if this instanceof HC_SizeofExpr then result = "SizeofExprOperator" else
    if this instanceof HC_AlignofType then result = "AlignofTypeOperator" else
    if this instanceof HC_AlignofExpr then result = "AlignofExprOperator" else
    if this instanceof HC_ArrayAggregateLiteral then result = "ArrayAggregateLiteral" else
    if this instanceof HC_ClassAggregateLiteral then result = "ClassAggreagateLiteral" else
    if this instanceof HC_DeleteExpr then result = "DeleteExpr" else
    if this instanceof HC_DeleteArrayExpr then result = "DeleteArrayExpr" else
    if this instanceof HC_ThrowExpr then result = "ThrowExpr" else
    if this instanceof HC_ReThrowExpr then result = "ReThrowExpr" else
    result = "error"
  }

  /**
   * Gets an example of an expression with this HC.
   * This is useful for things like implementing toString().
   */
  private Expr exampleExpr() {
    // Pick the expression with the minimum source location string. This is
    // just an arbitrary way to pick an expression with this `HC`.
    result =
       min(Expr e
       | this = hashCons(e)
       | e order by e.getLocation().toString())
  }

  /** Gets a textual representation of this element. */
  string toString() {
    result = exampleExpr().toString()
  }

  /** Gets the primary location of this element. */
  Location getLocation() {
    result = exampleExpr().getLocation()
  }
}

private predicate analyzableIntLiteral(Literal e) {
  strictcount (e.getValue().toInt()) = 1 and
  strictcount (e.getType().getUnspecifiedType()) = 1 and
  e.getType().getUnspecifiedType() instanceof IntegralType
}

private predicate mk_IntLiteral(int val, Type t, Expr e) {
  analyzableIntLiteral(e) and
  val = e.getValue().toInt() and
  t = e.getType().getUnspecifiedType()
}

private predicate analyzableEnumConstantAccess(EnumConstantAccess e) {
  strictcount (e.getValue().toInt()) = 1 and
  strictcount (e.getType().getUnspecifiedType()) = 1 and
  e.getType().getUnspecifiedType() instanceof Enum
}

private predicate mk_EnumConstantAccess(EnumConstant val, Type t, Expr e) {
  analyzableEnumConstantAccess(e) and
  val = e.(EnumConstantAccess).getTarget() and
  t = e.getType().getUnspecifiedType()
}

private predicate analyzableFloatLiteral(Literal e) {
  strictcount (e.getValue().toFloat()) = 1 and
  strictcount (e.getType().getUnspecifiedType()) = 1 and
  e.getType().getUnspecifiedType() instanceof FloatingPointType
}

private predicate mk_FloatLiteral(float val, Type t, Expr e) {
  analyzableFloatLiteral(e) and
  val = e.getValue().toFloat() and
  t = e.getType().getUnspecifiedType()
}

private predicate analyzableNullptr(NullValue e) {
  strictcount (e.getType().getUnspecifiedType()) = 1 and
  e.getType() instanceof NullPointerType
}

private predicate mk_Nullptr(Expr e) {
  analyzableNullptr(e)
}

private predicate analyzableStringLiteral(Literal e) {
  strictcount(e.getValue()) = 1 and
  strictcount(e.getType().getUnspecifiedType()) = 1 and
  e.getType().getUnspecifiedType().(ArrayType).getBaseType() instanceof CharType
}

private predicate mk_StringLiteral(string val, Type t, Expr e) {
  analyzableStringLiteral(e) and
  val = e.getValue() and
  t = e.getType().getUnspecifiedType() and
  t.(ArrayType).getBaseType() instanceof CharType
  
}

private predicate analyzableDotFieldAccess(DotFieldAccess access) {
  strictcount (access.getTarget()) = 1 and
  strictcount (access.getQualifier().getFullyConverted()) = 1
}

private predicate mk_DotFieldAccess(
  HashCons qualifier, Field target, DotFieldAccess access) {
  analyzableDotFieldAccess(access) and
  target = access.getTarget() and
  qualifier = hashCons(access.getQualifier().getFullyConverted())
}

private predicate analyzablePointerFieldAccess(PointerFieldAccess access) {
  strictcount (access.getTarget()) = 1 and
  strictcount (access.getQualifier().getFullyConverted()) = 1
}

private predicate mk_PointerFieldAccess(
  HashCons qualifier, Field target,
  PointerFieldAccess access) {
  analyzablePointerFieldAccess(access) and
  target = access.getTarget() and
  qualifier = hashCons(access.getQualifier().getFullyConverted())
}

/*
 * `obj->field` is equivalent to `(*obj).field`, so we need to wrap an
 * extra `HC_Deref` around the qualifier.
 */
private predicate mk_PointerFieldAccess_with_deref (HashCons new_qualifier, Field target,
  PointerFieldAccess access) {
  exists (HashCons qualifier
  | mk_PointerFieldAccess(qualifier, target, access) and
    new_qualifier = HC_Deref(qualifier))
}

private predicate analyzableImplicitThisFieldAccess(ImplicitThisFieldAccess access) {
  strictcount (access.getTarget()) = 1 and
  strictcount (access.getEnclosingFunction()) = 1
}

private predicate mk_ImplicitThisFieldAccess(Function fcn, Field target,
  ImplicitThisFieldAccess access) {
  analyzableImplicitThisFieldAccess(access) and
  target = access.getTarget() and
  fcn = access.getEnclosingFunction()
}

private predicate mk_ImplicitThisFieldAccess_with_qualifier( HashCons qualifier, Field target,
  ImplicitThisFieldAccess access) {
  exists (Function fcn
  | mk_ImplicitThisFieldAccess(fcn, target, access) and
    qualifier = HC_ThisExpr(fcn))
}

private predicate mk_ImplicitThisFieldAccess_with_deref(HashCons new_qualifier, Field target,
  ImplicitThisFieldAccess access) {
  exists (HashCons qualifier
  | mk_ImplicitThisFieldAccess_with_qualifier(
      qualifier, target, access) and
    new_qualifier = HC_Deref(qualifier))
}

private predicate analyzableVariable(VariableAccess access) {
  not (access instanceof FieldAccess) and
  strictcount (access.getTarget()) = 1
}

private predicate mk_Variable(Variable x, VariableAccess access) {
  analyzableVariable(access) and
  x = access.getTarget()
}

private predicate analyzableConversion(Conversion conv) {
  strictcount (conv.getType().getUnspecifiedType()) = 1 and
  strictcount (conv.getExpr()) = 1
}

private predicate mk_Conversion(Type t, HashCons child, Conversion conv) {
  analyzableConversion(conv) and
  t = conv.getType().getUnspecifiedType() and
  child = hashCons(conv.getExpr())
}

private predicate analyzableBinaryOp(BinaryOperation op) {
  strictcount (op.getLeftOperand().getFullyConverted()) = 1 and
  strictcount (op.getRightOperand().getFullyConverted()) = 1 and
  strictcount (op.getOperator()) = 1
}

private predicate mk_BinaryOp(HashCons lhs, HashCons rhs, string opname, BinaryOperation op) {
  analyzableBinaryOp(op) and
  lhs = hashCons(op.getLeftOperand().getFullyConverted()) and
  rhs = hashCons(op.getRightOperand().getFullyConverted()) and
  opname = op.getOperator()
}

private predicate analyzableUnaryOp(UnaryOperation op) {
  not (op instanceof PointerDereferenceExpr) and
  strictcount (op.getOperand().getFullyConverted()) = 1 and
  strictcount (op.getOperator()) = 1
}

private predicate mk_UnaryOp(HashCons child, string opname, UnaryOperation op) {
  analyzableUnaryOp(op) and
  child = hashCons(op.getOperand().getFullyConverted()) and
  opname = op.getOperator()
}

private predicate analyzableThisExpr(ThisExpr thisExpr) {
  strictcount(thisExpr.getEnclosingFunction()) = 1
}

private predicate mk_ThisExpr(Function fcn, ThisExpr thisExpr) {
  analyzableThisExpr(thisExpr) and
  fcn = thisExpr.getEnclosingFunction()
}

private predicate analyzableArrayAccess(ArrayExpr ae) {
  strictcount (ae.getArrayBase().getFullyConverted()) = 1 and
  strictcount (ae.getArrayOffset().getFullyConverted()) = 1
}

private predicate mk_ArrayAccess(HashCons base, HashCons offset, ArrayExpr ae) {
  analyzableArrayAccess(ae) and
  base = hashCons(ae.getArrayBase().getFullyConverted()) and
  offset = hashCons(ae.getArrayOffset().getFullyConverted())
}

private predicate analyzablePointerDereferenceExpr(PointerDereferenceExpr deref) {
  strictcount (deref.getOperand().getFullyConverted()) = 1
}

private predicate mk_Deref(HashCons p, PointerDereferenceExpr deref) {
  analyzablePointerDereferenceExpr(deref) and
  p = hashCons(deref.getOperand().getFullyConverted())
}

private predicate analyzableNonmemberFunctionCall(FunctionCall fc) {
  forall(int i |
    exists(fc.getArgument(i)) |
    strictcount(fc.getArgument(i).getFullyConverted()) = 1
  ) and
  strictcount(fc.getTarget()) = 1 and
  not exists(fc.getQualifier())
}

private predicate mk_NonmemberFunctionCall(Function fcn, HC_Args args, FunctionCall fc
) {
  fc.getTarget() = fcn and
  analyzableNonmemberFunctionCall(fc) and
  (
    exists(HashCons head, HC_Args tail |
      args = HC_ArgCons(fcn, head, fc.getNumberOfArguments() - 1, tail) and
      mk_ArgCons(fcn, head, fc.getNumberOfArguments() - 1, tail, fc)
    )
    or
    fc.getNumberOfArguments() = 0 and
    args = HC_EmptyArgs(fcn)
  )
}

private predicate analyzableMemberFunctionCall(
  FunctionCall fc) {
  forall(int i |
  exists(fc.getArgument(i)) |
    strictcount(fc.getArgument(i).getFullyConverted()) = 1
  ) and
  strictcount(fc.getTarget()) = 1 and
  strictcount(fc.getQualifier().getFullyConverted()) = 1
}

private predicate mk_MemberFunctionCall(
  Function fcn,
  HashCons qual,
  HC_Args args,
  FunctionCall fc
) {
  fc.getTarget() = fcn and
  analyzableMemberFunctionCall(fc) and
  hashCons(fc.getQualifier().getFullyConverted()) = qual and
  (
    exists(HashCons head, HC_Args tail |
      args = HC_ArgCons(fcn, head, fc.getNumberOfArguments() - 1, tail) and
      mk_ArgCons(fcn, head, fc.getNumberOfArguments() - 1, tail, fc)
    )
    or
    fc.getNumberOfArguments() = 0 and
    args = HC_EmptyArgs(fcn)
  )
}

private predicate analyzableFunctionCall(
  FunctionCall fc
) {
  analyzableNonmemberFunctionCall(fc)
  or
  analyzableMemberFunctionCall(fc)
}

/**
 * Holds if `fc` is a call to `fcn`, `fc`'s first `i` arguments have hash-cons
 * `list`, and `fc`'s argument at index `i` has hash-cons `hc`.
 */
private predicate mk_ArgCons(Function fcn, HashCons hc, int i, HC_Args list, FunctionCall fc) {
  analyzableFunctionCall(fc) and
  fc.getTarget() = fcn and
  hc = hashCons(fc.getArgument(i).getFullyConverted()) and
  (
    exists(HashCons head, HC_Args tail |
      list = HC_ArgCons(fcn, head, i - 1, tail) and
      mk_ArgCons(fcn, head, i - 1, tail, fc) and
      i > 0
    )
    or
    i = 0 and
    list = HC_EmptyArgs(fcn)
  )
}


/**
 * Holds if `fc` is a call to `fcn`, `fc`'s first `i` arguments have hash-cons
 * `list`, and `fc`'s argument at index `i` has hash-cons `hc`.
 */
private predicate mk_AllocArgCons(Function fcn, HashCons hc, int i, HC_Alloc list, boolean aligned, FunctionCall fc) {
  analyzableFunctionCall(fc) and
  fc.getTarget() = fcn and
  hc = hashCons(fc.getArgument(i).getFullyConverted()) and
  (
    exists(HashCons head, HC_Alloc tail |
      list = HC_AllocArgCons(fcn, head, i - 1, tail, aligned) and
      mk_AllocArgCons(fcn, head, i - 1, tail, aligned, fc) and
      (
        aligned = true and
        i > 2
        or
        aligned = false and
        i > 1
      )
    )
    or
    (
      aligned = true and
      i = 2
      or
      aligned = false and
      i = 1
    ) and
    list = HC_EmptyAllocArgs(fcn)
  )
}

private predicate mk_HasInit(HashCons hc, NewOrNewArrayExpr new) {
  hc = hashCons(new.(NewExpr).getInitializer()) or
  hc = hashCons(new.(NewArrayExpr).getInitializer())
}

private predicate mk_HasAlign(HashCons hc, NewOrNewArrayExpr new) {
  hc = hashCons(new.getAlignmentArgument())
}

private predicate analyzableNewExpr(NewExpr new) {
  strictcount(new.getAllocatedType()) = 1 and
  (
    not exists(new.getAllocatorCall())
    or
    strictcount(new.getAllocatorCall()) = 1
  ) and (
    not exists(new.getInitializer())
    or
    strictcount(new.getInitializer()) = 1
  )
}

private predicate mk_NewExpr(Type t, HC_Alloc alloc, HC_Init init, HC_Align align, boolean aligned,
  NewExpr new) {
  analyzableNewExpr(new) and
  t = new.getAllocatedType() and
  (
    align = HC_HasAlign(hashCons(new.getAlignmentArgument())) and
    aligned = true
    or
    not new.hasAlignedAllocation() and
    align = HC_NoAlign() and
    aligned = false
  )
  and
  (
    exists(FunctionCall fc, HashCons head, HC_Alloc tail |
      fc = new.getAllocatorCall() and
      alloc = HC_AllocArgCons(fc.getTarget(), head, fc.getNumberOfArguments() - 1, tail, aligned) and
      mk_AllocArgCons(fc.getTarget(), head, fc.getNumberOfArguments() - 1, tail, aligned, fc)
    )
    or
    exists(FunctionCall fc |
      fc = new.getAllocatorCall() and
      (
        aligned = true and
        fc.getNumberOfArguments() = 2
        or
        aligned = false and
        fc.getNumberOfArguments() = 1
      ) and
      alloc = HC_EmptyAllocArgs(fc.getTarget())
    )
    or
    not exists(new.getAllocatorCall()) and
    alloc = HC_NoAlloc()
  )
  and
  (
    init = HC_HasInit(hashCons(new.getInitializer()))
    or
    not exists(new.getInitializer()) and
    init = HC_NoInit()
  )
}

private predicate analyzableNewArrayExpr(NewArrayExpr new) {
  strictcount(new.getAllocatedType().getUnspecifiedType()) = 1 and
  strictcount(new.getAllocatedType().getUnspecifiedType()) = 1 and
  (
    not exists(new.getAllocatorCall())
    or
    strictcount(new.getAllocatorCall().getFullyConverted()) = 1
  ) and (
    not exists(new.getInitializer())
    or
    strictcount(new.getInitializer().getFullyConverted()) = 1
  )
}

private predicate mk_NewArrayExpr(Type t, HC_Alloc alloc, HC_Init init, HC_Align align,
  boolean aligned, NewArrayExpr new) {
  analyzableNewArrayExpr(new) and
  t = new.getAllocatedType() and
  (
    align = HC_HasAlign(hashCons(new.getAlignmentArgument())) and
    aligned = true
    or
    not new.hasAlignedAllocation() and
    align = HC_NoAlign() and
    aligned = false
  )
  and
  (
    exists(FunctionCall fc, HashCons head, HC_Alloc tail |
      fc = new.getAllocatorCall() and
      alloc = HC_AllocArgCons(fc.getTarget(), head, fc.getNumberOfArguments() - 1, tail, aligned) and
      mk_AllocArgCons(fc.getTarget(), head, fc.getNumberOfArguments() - 1, tail, aligned, fc)
    )
    or
    exists(FunctionCall fc |
      fc = new.getAllocatorCall() and
      (
        aligned = true and
        fc.getNumberOfArguments() = 2
        or
        aligned = false and
        fc.getNumberOfArguments() = 1
      ) and
      alloc = HC_EmptyAllocArgs(fc.getTarget())
    )
    or
    not exists(new.getAllocatorCall()) and
    alloc = HC_NoAlloc()
  )
  and
  (
    init = HC_HasInit(hashCons(new.getInitializer()))
    or
    not exists(new.getInitializer()) and
    init = HC_NoInit()
  )
}

private predicate analyzableDeleteExpr(DeleteExpr e) {
  strictcount(e.getAChild().getFullyConverted()) = 1
}

private predicate mk_DeleteExpr(HashCons hc, DeleteExpr e) {
  analyzableDeleteExpr(e) and
  hc = hashCons(e.getAChild().getFullyConverted())
}

private predicate analyzableDeleteArrayExpr(DeleteArrayExpr e) {
  strictcount(e.getAChild().getFullyConverted()) = 1
}

private predicate mk_DeleteArrayExpr(HashCons hc, DeleteArrayExpr e) {
  analyzableDeleteArrayExpr(e) and
  hc = hashCons(e.getAChild().getFullyConverted())
}

private predicate analyzableSizeofType(SizeofTypeOperator e) {
  strictcount(e.getType().getUnspecifiedType()) = 1 and
  strictcount(e.getTypeOperand()) = 1
}

private predicate mk_SizeofType(Type t, SizeofTypeOperator e) {
  analyzableSizeofType(e) and
  t = e.getTypeOperand()
}

private predicate analyzableSizeofExpr(Expr e) {
  e instanceof SizeofExprOperator and
  strictcount(e.getAChild().getFullyConverted()) = 1
}

private predicate mk_SizeofExpr(HashCons child, SizeofExprOperator e) {
  analyzableSizeofExpr(e) and
  child = hashCons(e.getAChild())
}

private predicate analyzableAlignofType(AlignofTypeOperator e) {
  strictcount(e.getType().getUnspecifiedType()) = 1 and
  strictcount(e.getTypeOperand()) = 1
}

private predicate mk_AlignofType(Type t, AlignofTypeOperator e) {
  analyzableAlignofType(e) and
  t = e.getTypeOperand()
}

private predicate analyzableAlignofExpr(AlignofExprOperator e) {
  strictcount(e.getExprOperand()) = 1
}

private predicate mk_AlignofExpr(HashCons child, AlignofExprOperator e) {
  analyzableAlignofExpr(e) and
  child = hashCons(e.getAChild())
}

private predicate mk_FieldCons(Class c, int i, Field f, HashCons hc, HC_Fields hcf,
  ClassAggregateLiteral cal) {
  analyzableClassAggregateLiteral(cal) and
  cal.getType().getUnspecifiedType() = c and
  exists(Expr e |
    e = cal.getFieldExpr(f).getFullyConverted() and
    e = cal.getChild(i).getFullyConverted() and
    hc = hashCons(e) and
    (
      exists(HashCons head, Field f2, HC_Fields tail |
        hcf = HC_FieldCons(c, i-1, f2, head, tail) and
        cal.getChild(i-1).getFullyConverted() = cal.getFieldExpr(f2).getFullyConverted() and
        mk_FieldCons(c, i-1, f2, head, tail, cal)
        
      )
      or
      i = 0 and
      hcf = HC_EmptyFields(c)
    )
  )
}

private predicate analyzableClassAggregateLiteral(ClassAggregateLiteral cal) {
  forall(int i |
    exists(cal.getChild(i)) |
    strictcount(cal.getChild(i).getFullyConverted()) = 1 and
    strictcount(Field f | cal.getChild(i) = cal.getFieldExpr(f)) = 1
  )
}

private predicate mk_ClassAggregateLiteral(Class c, HC_Fields hcf, ClassAggregateLiteral cal) {
  analyzableClassAggregateLiteral(cal) and
  c = cal.getType().getUnspecifiedType() and
  (
    exists(HC_Fields tail, Expr e, Field f |
      e = cal.getChild(cal.getNumChild() - 1).getFullyConverted() and
      e = cal.getFieldExpr(f).getFullyConverted() and
      hcf = HC_FieldCons(c, cal.getNumChild() - 1, f, hashCons(e), tail) and
      mk_FieldCons(c, cal.getNumChild() - 1, f, hashCons(e), tail, cal)
    )
    or
    cal.getNumChild() = 0 and
    hcf = HC_EmptyFields(c)
  )
}

private predicate analyzableArrayAggregateLiteral(ArrayAggregateLiteral aal) {
  forall(int i |
    exists(aal.getChild(i)) |
    strictcount(aal.getChild(i).getFullyConverted()) = 1
  )
}

private predicate mk_ArrayCons(Type t, int i, HashCons hc, HC_Array hca, ArrayAggregateLiteral aal) {
  t = aal.getType().getUnspecifiedType() and
  hc = hashCons(aal.getChild(i)) and
  (
    exists(HC_Array tail, HashCons head |
      hca = HC_ArrayCons(t, i - 1, head, tail) and
      mk_ArrayCons(t, i-1, head, tail, aal)
    )
    or
    i = 0 and
    hca = HC_EmptyArray(t)
  )
}

private predicate mk_ArrayAggregateLiteral(Type t, HC_Array hca, ArrayAggregateLiteral aal) {
  t = aal.getType().getUnspecifiedType() and
  (
    exists(HashCons head, HC_Array tail |
      hca = HC_ArrayCons(t, aal.getNumChild() - 1, head, tail) and
      mk_ArrayCons(t, aal.getNumChild() - 1, head, tail, aal)
    )
    or
    aal.getNumChild() = 0 and
    hca = HC_EmptyArray(t)
  )
}

private predicate analyzableThrowExpr(ThrowExpr te) {
  strictcount(te.getExpr().getFullyConverted()) = 1
}

private predicate mk_ThrowExpr(HashCons hc, ThrowExpr te) {
  analyzableThrowExpr(te) and
  hc.getAnExpr() = te.getExpr().getFullyConverted()
}

private predicate analyzableReThrowExpr(ReThrowExpr rte) {
  any()
}

private predicate mk_ReThrowExpr(ReThrowExpr te) {
  any()
}

/** Gets the hash-cons of expression `e`. */
cached HashCons hashCons(Expr e) {
  exists (int val, Type t
  | mk_IntLiteral(val, t, e) and
    result = HC_IntLiteral(val, t))
  or
  exists (EnumConstant val, Type t
  | mk_EnumConstantAccess(val, t, e) and
    result = HC_EnumConstantAccess(val, t))
  or
  exists (float val, Type t
  | mk_FloatLiteral(val, t, e) and
    result = HC_FloatLiteral(val, t))
  or
  exists (string val, Type t
  | mk_StringLiteral(val, t, e) and
    result = HC_StringLiteral(val, t))
  or
  exists (Variable x
  | mk_Variable(x, e) and
    result = HC_Variable(x))
  or
  exists (HashCons qualifier, Field target
  | mk_DotFieldAccess(qualifier, target, e) and
    result = HC_FieldAccess(qualifier, target))
  or
  exists (HashCons qualifier, Field target
  | mk_PointerFieldAccess_with_deref(qualifier, target, e) and
    result = HC_FieldAccess(qualifier, target))
  or
  exists (HashCons qualifier, Field target
  | mk_ImplicitThisFieldAccess_with_deref(qualifier, target, e) and
    result = HC_FieldAccess(qualifier, target))
  or
  exists (Function fcn
  | mk_ThisExpr(fcn, e) and
    result = HC_ThisExpr(fcn))
  or
  exists (Type t, HashCons child
  | mk_Conversion(t, child, e) and
    result = HC_Conversion(t, child))
  or
  exists (HashCons lhs, HashCons rhs, string opname
  | mk_BinaryOp(lhs, rhs, opname, e) and
    result = HC_BinaryOp(lhs, rhs, opname))
  or
  exists (HashCons child, string opname
  | mk_UnaryOp(child, opname, e) and
    result = HC_UnaryOp(child, opname))
  or
  exists (HashCons x, HashCons i
  | mk_ArrayAccess(x, i, e) and
    result = HC_ArrayAccess(x, i))
  or
  exists (HashCons p
  | mk_Deref(p, e) and
    result = HC_Deref(p))
  or
  exists(Function fcn, HC_Args args
  | mk_NonmemberFunctionCall(fcn, args, e) and
    result = HC_NonmemberFunctionCall(fcn, args)
  )
  or
  exists(Function fcn, HashCons qual, HC_Args args
  | mk_MemberFunctionCall(fcn, qual, args, e) and
    result = HC_MemberFunctionCall(fcn, qual, args)
  )
  or
  exists(Type t, HC_Alloc alloc, HC_Init init, HC_Align align, boolean aligned
  | mk_NewExpr(t, alloc, init, align, aligned, e) and
    result = HC_NewExpr(t, alloc, init, align)
  )
  or
  exists(Type t, HC_Alloc alloc, HC_Init init, HC_Align align, boolean aligned
  | mk_NewArrayExpr(t, alloc, init, align, aligned, e) and
    result = HC_NewArrayExpr(t, alloc, init, align)
  )
  or
  exists(Type t
  | mk_SizeofType(t, e) and
    result = HC_SizeofType(t)
  )
  or
  exists(HashCons child
  | mk_SizeofExpr(child, e) and
    result = HC_SizeofExpr(child)
  )
  or
  exists(Type t
  | mk_AlignofType(t, e) and
    result = HC_AlignofType(t)
  )
  or
  exists(HashCons child
  | mk_AlignofExpr(child, e) and
    result = HC_AlignofExpr(child)
  )
  or
  exists(Class c, HC_Fields hfc
  | mk_ClassAggregateLiteral(c, hfc, e) and
    result = HC_ClassAggregateLiteral(c, hfc)
  )
  or
  exists(Type t, HC_Array hca
  | mk_ArrayAggregateLiteral(t, hca, e) and
    result = HC_ArrayAggregateLiteral(t, hca)
  )
  or
  exists(HashCons child
  | mk_DeleteExpr(child, e) and
    result = HC_DeleteExpr(child)
  )
  or
  exists(HashCons child
  | mk_DeleteArrayExpr(child, e) and
    result = HC_DeleteArrayExpr(child)
  )
  or
  exists(HashCons child
  | mk_ThrowExpr(child, e) and
    result = HC_ThrowExpr(child)
  )
  or
  (
    mk_ReThrowExpr(e) and
    result = HC_ReThrowExpr()
  )
  or
  (
    mk_Nullptr(e) and
    result = HC_Nullptr()
  )

  or
  (not analyzableExpr(e,_) and result = HC_Unanalyzable(e))
}
/**
 * Holds if the expression is explicitly handled by `hashCons`.
 * Unanalyzable expressions still need to be given a hash-cons,
 * but it will be a unique number that is not shared with any other
 * expression.
 */
predicate analyzableExpr(Expr e, string kind) {
  (analyzableIntLiteral(e) and kind = "IntLiteral") or
  (analyzableEnumConstantAccess(e) and kind = "EnumConstantAccess") or
  (analyzableFloatLiteral(e) and kind = "FloatLiteral") or
  (analyzableStringLiteral(e) and kind = "StringLiteral") or
  (analyzableNullptr(e) and kind = "Nullptr") or
  (analyzableDotFieldAccess(e) and kind = "DotFieldAccess") or
  (analyzablePointerFieldAccess(e) and kind = "PointerFieldAccess") or
  (analyzableImplicitThisFieldAccess(e) and kind = "ImplicitThisFieldAccess") or
  (analyzableVariable(e) and kind = "Variable") or
  (analyzableConversion(e) and kind = "Conversion") or
  (analyzableBinaryOp(e) and kind = "BinaryOp") or
  (analyzableUnaryOp(e) and kind = "UnaryOp") or
  (analyzableThisExpr(e) and kind = "ThisExpr") or
  (analyzableArrayAccess(e) and kind = "ArrayAccess") or
  (analyzablePointerDereferenceExpr(e) and kind = "PointerDereferenceExpr") or
  (analyzableNonmemberFunctionCall(e) and kind = "NonmemberFunctionCall") or
  (analyzableMemberFunctionCall(e) and kind = "MemberFunctionCall") or
  (analyzableNewExpr(e) and kind = "NewExpr") or
  (analyzableNewArrayExpr(e) and kind = "NewArrayExpr") or
  (analyzableSizeofType(e) and kind = "SizeofTypeOperator") or
  (analyzableSizeofExpr(e) and kind = "SizeofExprOperator") or
  (analyzableAlignofType(e) and kind = "AlignofTypeOperator") or
  (analyzableAlignofExpr(e) and kind = "AlignofExprOperator") or
  (analyzableClassAggregateLiteral(e) and kind = "ClassAggregateLiteral") or
  (analyzableArrayAggregateLiteral(e) and kind = "ArrayAggregateLiteral") or
  (analyzableDeleteExpr(e) and kind = "DeleteExpr") or
  (analyzableDeleteArrayExpr(e) and kind = "DeleteArrayExpr") or
  (analyzableThrowExpr(e) and kind = "ThrowExpr") or
  (analyzableReThrowExpr(e) and kind = "ReThrowExpr")
}
