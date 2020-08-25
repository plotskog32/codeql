/**
 * Provides classes for performing local (intra-procedural) and
 * global (inter-procedural) taint-tracking analyses.
 *
 * We define _taint propagation_ informally to mean that a substantial part of
 * the information from the source is preserved at the sink. For example, taint
 * propagates from `x` to `x + 100`, but it does not propagate from `x` to `x >
 * 100` since we consider a single bit of information to be too little.
 */

private import semmle.code.cpp.models.interfaces.DataFlow
private import semmle.code.cpp.models.interfaces.Taint
private import semmle.code.cpp.models.implementations.Iterator

private module DataFlow {
  import semmle.code.cpp.dataflow.internal.DataFlowUtil
}

/**
 * Holds if taint propagates from `nodeFrom` to `nodeTo` in exactly one local
 * (intra-procedural) step.
 */
predicate localTaintStep(DataFlow::Node src, DataFlow::Node sink) {
  DataFlow::localFlowStep(src, sink) or
  localAdditionalTaintStep(src, sink)
}

/**
 * Holds if the additional step from `src` to `sink` should be included in all
 * global taint flow configurations.
 */
predicate defaultAdditionalTaintStep(DataFlow::Node src, DataFlow::Node sink) {
  localAdditionalTaintStep(src, sink)
}

/**
 * Holds if `node` should be a barrier in all global taint flow configurations
 * but not in local taint.
 */
predicate defaultTaintBarrier(DataFlow::Node node) { none() }

/**
 * Holds if taint can flow in one local step from `nodeFrom` to `nodeTo` excluding
 * local data flow steps. That is, `nodeFrom` and `nodeTo` are likely to represent
 * different objects.
 */
predicate localAdditionalTaintStep(DataFlow::Node nodeFrom, DataFlow::Node nodeTo) {
  // Taint can flow through expressions that alter the value but preserve
  // more than one bit of it _or_ expressions that follow data through
  // pointer indirections.
  exists(Expr exprFrom, Expr exprTo |
    exprFrom = nodeFrom.asExpr() and
    exprTo = nodeTo.asExpr()
  |
    exprFrom = exprTo.getAChild() and
    not noParentExprFlow(exprFrom, exprTo) and
    not noFlowFromChildExpr(exprTo)
    or
    // Taint can flow from the `x` variable in `x++` to all subsequent
    // accesses to the unmodified `x` variable.
    //
    // `DataFlow` without taint specifies flow from `++x` and `x += 1` into the
    // variable `x` and thus into subsequent accesses because those expressions
    // compute the same value as `x`. This is not the case for `x++`, which
    // computes a different value, so we have to add that ourselves for taint
    // tracking. The flow from expression `x` into `x++` etc. is handled in the
    // case above.
    exprTo = DataFlow::getAnAccessToAssignedVariable(exprFrom.(PostfixCrementOperation))
    or
    // In `for (char c : s) { ... c ... }`, this rule propagates taint from `s`
    // to `c`.
    exists(RangeBasedForStmt rbf |
      exprFrom = rbf.getRange() and
      // It's guaranteed up to at least C++20 that the range-based for loop
      // desugars to a variable with an initializer.
      exprTo = rbf.getVariable().getInitializer().getExpr()
    )
  )
  or
  // Taint can flow through modeled functions
  exprToExprStep(nodeFrom.asExpr(), nodeTo.asExpr())
  or
  exprToDefinitionByReferenceStep(nodeFrom.asExpr(), nodeTo.asDefiningArgument())
  or
  exprToPartialDefinitionStep(nodeFrom.asExpr(), nodeTo.asPartialDefinition())
  or
  // Reverse taint: taint that flows from the post-update node of a reference
  // returned by a function call, back into the qualifier of that function.
  // This allows taint to flow 'in' through references returned by a modeled
  // function such as `operator[]`.
  exists(TaintFunction f, Call call, FunctionInput inModel, FunctionOutput outModel |
    call.getTarget() = f and
    inModel.isReturnValueDeref() and
    outModel.isQualifierObject() and
    f.hasTaintFlow(inModel, outModel) and
    nodeFrom.(DataFlow::PostUpdateNode).getPreUpdateNode().asExpr() = call and
    nodeTo.asDefiningArgument() = call.getQualifier()
  )
}

/**
 * Holds if taint may propagate from `source` to `sink` in zero or more local
 * (intra-procedural) steps.
 */
predicate localTaint(DataFlow::Node source, DataFlow::Node sink) { localTaintStep*(source, sink) }

/**
 * Holds if taint can flow from `e1` to `e2` in zero or more
 * local (intra-procedural) steps.
 */
predicate localExprTaint(Expr e1, Expr e2) {
  localTaint(DataFlow::exprNode(e1), DataFlow::exprNode(e2))
}

/**
 * Holds if we do not propagate taint from `fromExpr` to `toExpr`
 * even though `toExpr` is the AST parent of `fromExpr`.
 */
private predicate noParentExprFlow(Expr fromExpr, Expr toExpr) {
  fromExpr = toExpr.(ConditionalExpr).getCondition()
  or
  fromExpr = toExpr.(CommaExpr).getLeftOperand()
  or
  fromExpr = toExpr.(AssignExpr).getLValue() // LHS of `=`
}

/**
 * Holds if we do not propagate taint from a child of `e` to `e` itself.
 */
private predicate noFlowFromChildExpr(Expr e) {
  e instanceof ComparisonOperation
  or
  e instanceof LogicalAndExpr
  or
  e instanceof LogicalOrExpr
  or
  e instanceof Call
  or
  e instanceof SizeofOperator
  or
  e instanceof AlignofOperator
  or
  e instanceof ClassAggregateLiteral
  or
  e instanceof FieldAccess
}

private predicate exprToExprStep(Expr exprIn, Expr exprOut) {
  exists(DataFlowFunction f, Call call, FunctionOutput outModel |
    call.getTarget() = f and
    exprOut = call and
    outModel.isReturnValueDeref() and
    exists(int argInIndex, FunctionInput inModel | f.hasDataFlow(inModel, outModel) |
      // Taint flows from a pointer to a dereference, which DataFlow does not handle
      // dest_ptr = strdup(tainted_ptr)
      inModel.isParameterDeref(argInIndex) and
      exprIn = call.getArgument(argInIndex)
      or
      inModel.isParameter(argInIndex) and
      exprIn = call.getArgument(argInIndex)
    )
  )
  or
  exists(TaintFunction f, Call call, FunctionInput inModel, FunctionOutput outModel |
    call.getTarget() = f and
    (
      exprOut = call and
      outModel.isReturnValueDeref()
      or
      exprOut = call and
      outModel.isReturnValue()
    ) and
    f.hasTaintFlow(inModel, outModel) and
    (
      exists(int argInIndex |
        inModel.isParameterDeref(argInIndex) and
        exprIn = call.getArgument(argInIndex)
        or
        inModel.isParameterDeref(argInIndex) and
        call.passesByReference(argInIndex, exprIn)
        or
        inModel.isParameter(argInIndex) and
        exprIn = call.getArgument(argInIndex)
      )
      or
      inModel.isQualifierObject() and
      exprIn = call.getQualifier()
    )
  )
  or
  exists(Variable iterator, Variable collection |
    assignmentViaIterator(iterator, exprIn) and
    isIteratorForCollection(iterator, collection) and
    collection.getAnAccess() = exprOut
  )
}

private predicate exprToDefinitionByReferenceStep(Expr exprIn, Expr argOut) {
  exists(DataFlowFunction f, Call call, FunctionOutput outModel, int argOutIndex |
    call.getTarget() = f and
    argOut = call.getArgument(argOutIndex) and
    outModel.isParameterDeref(argOutIndex) and
    exists(int argInIndex, FunctionInput inModel | f.hasDataFlow(inModel, outModel) |
      // Taint flows from a pointer to a dereference, which DataFlow does not handle
      // memcpy(&dest_var, tainted_ptr, len)
      inModel.isParameterDeref(argInIndex) and
      exprIn = call.getArgument(argInIndex)
      or
      inModel.isParameter(argInIndex) and
      exprIn = call.getArgument(argInIndex)
    )
  )
  or
  exists(
    TaintFunction f, Call call, FunctionInput inModel, FunctionOutput outModel, int argOutIndex
  |
    call.getTarget() = f and
    argOut = call.getArgument(argOutIndex) and
    outModel.isParameterDeref(argOutIndex) and
    f.hasTaintFlow(inModel, outModel) and
    (
      exists(int argInIndex |
        inModel.isParameterDeref(argInIndex) and
        exprIn = call.getArgument(argInIndex)
        or
        inModel.isParameterDeref(argInIndex) and
        call.passesByReference(argInIndex, exprIn)
        or
        inModel.isParameter(argInIndex) and
        exprIn = call.getArgument(argInIndex)
      )
      or
      inModel.isQualifierObject() and
      exprIn = call.getQualifier()
    )
  )
}

private predicate exprToPartialDefinitionStep(Expr exprIn, Expr exprOut) {
  exists(TaintFunction f, Call call, FunctionInput inModel, FunctionOutput outModel |
    call.getTarget() = f and
    (
      exprOut = call.getQualifier() and
      outModel.isQualifierObject()
    ) and
    f.hasTaintFlow(inModel, outModel) and
    exists(int argInIndex |
      inModel.isParameterDeref(argInIndex) and
      exprIn = call.getArgument(argInIndex)
      or
      inModel.isParameterDeref(argInIndex) and
      call.passesByReference(argInIndex, exprIn)
      or
      inModel.isParameter(argInIndex) and
      exprIn = call.getArgument(argInIndex)
    )
  )
}

private predicate isIteratorForCollection(Variable iterator, Variable collection) {
  exists(Call beginOrEnd |
    beginOrEnd.getTarget() instanceof BeginOrEndFunction and
    beginOrEnd.getQualifier() = collection.getAnAccess() and
    iterator.getAnAssignedValue() = beginOrEnd
  )
}

private predicate assignmentViaIterator(Variable iterator, Expr rvalue) {
  exists(Assignment a, Call c |
    c.getTarget() instanceof IteratorArrayMemberOperator and
    c.getQualifier() = iterator.getAnAccess()
    or
    c.getTarget() instanceof IteratorPointerDereferenceMemberOperator and
    c.getQualifier() = iterator.getAnAccess()
    or
    c.getTarget() instanceof IteratorPointerDereferenceOperator and
    c.getArgument(0) = iterator.getAnAccess()
    |
    c = a.getLValue() and
    rvalue = a.getRValue()
  )
}
