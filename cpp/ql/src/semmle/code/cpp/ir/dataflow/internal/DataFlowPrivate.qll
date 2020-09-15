private import cpp
private import DataFlowUtil
private import semmle.code.cpp.ir.IR
private import DataFlowDispatch

/**
 * A data flow node that occurs as the argument of a call and is passed as-is
 * to the callable. Instance arguments (`this` pointer) are also included.
 */
class ArgumentNode extends InstructionNode {
  ArgumentNode() {
    exists(CallInstruction call |
      instr = call.getAnArgument()
      or
      instr.(ReadSideEffectInstruction).getPrimaryInstruction() = call
    )
  }

  /**
   * Holds if this argument occurs at the given position in the given call.
   * The instance argument is considered to have index `-1`.
   */
  predicate argumentOf(DataFlowCall call, int pos) {
    instr = call.getPositionalArgument(pos)
    or
    instr = call.getThisArgument() and pos = -1
    or
    exists(ReadSideEffectInstruction read |
      read = instr and
      read.getPrimaryInstruction() = call and
      pos = getArgumentPosOfSideEffect(read.getIndex())
    )
  }

  /** Gets the call in which this node is an argument. */
  DataFlowCall getCall() { this.argumentOf(result, _) }
}

private newtype TReturnKind =
  TNormalReturnKind() or
  TIndirectReturnKind(ParameterIndex index)

/**
 * A return kind. A return kind describes how a value can be returned
 * from a callable. For C++, this is simply a function return.
 */
class ReturnKind extends TReturnKind {
  /** Gets a textual representation of this return kind. */
  abstract string toString();
}

private class NormalReturnKind extends ReturnKind, TNormalReturnKind {
  override string toString() { result = "return" }
}

private class IndirectReturnKind extends ReturnKind, TIndirectReturnKind {
  ParameterIndex index;

  IndirectReturnKind() { this = TIndirectReturnKind(index) }

  override string toString() { result = "outparam[" + index.toString() + "]" }
}

/** A data flow node that occurs as the result of a `ReturnStmt`. */
class ReturnNode extends InstructionNode {
  Instruction primary;

  ReturnNode() {
    exists(ReturnValueInstruction ret | instr = ret.getReturnValue() and primary = ret)
    or
    exists(ReturnIndirectionInstruction rii |
      instr = rii.getSideEffectOperand().getAnyDef() and primary = rii
    )
  }

  /** Gets the kind of this returned value. */
  abstract ReturnKind getKind();
}

class ReturnValueNode extends ReturnNode {
  override ReturnValueInstruction primary;

  override ReturnKind getKind() { result = TNormalReturnKind() }
}

class ReturnIndirectionNode extends ReturnNode {
  override ReturnIndirectionInstruction primary;

  override ReturnKind getKind() {
    result = TIndirectReturnKind(-1) and
    primary.isThisIndirection()
    or
    result = TIndirectReturnKind(primary.getParameter().getIndex())
  }
}

/** A data flow node that represents the output of a call. */
class OutNode extends InstructionNode {
  OutNode() {
    instr instanceof CallInstruction or
    instr instanceof WriteSideEffectInstruction
  }

  /** Gets the underlying call. */
  abstract DataFlowCall getCall();

  abstract ReturnKind getReturnKind();
}

private class CallOutNode extends OutNode {
  override CallInstruction instr;

  override DataFlowCall getCall() { result = instr }

  override ReturnKind getReturnKind() { result instanceof NormalReturnKind }
}

private class SideEffectOutNode extends OutNode {
  override WriteSideEffectInstruction instr;

  override DataFlowCall getCall() { result = instr.getPrimaryInstruction() }

  override ReturnKind getReturnKind() { result = TIndirectReturnKind(instr.getIndex()) }
}

/**
 * Gets a node that can read the value returned from `call` with return kind
 * `kind`.
 */
OutNode getAnOutNode(DataFlowCall call, ReturnKind kind) {
  // There should be only one `OutNode` for a given `(call, kind)` pair. Showing the optimizer that
  // this is true helps it make better decisions downstream, especially in virtual dispatch.
  result =
    unique(OutNode outNode |
      outNode.getCall() = call and
      outNode.getReturnKind() = kind
    )
}

/**
 * Holds if data can flow from `node1` to `node2` in a way that loses the
 * calling context. For example, this would happen with flow through a
 * global or static variable.
 */
predicate jumpStep(Node n1, Node n2) { none() }

/**
 * Gets a field corresponding to the bit range `[startBit..endBit)` of class `c`, if any.
 */
private Field getAField(Class c, int startBit, int endBit) {
  result.getDeclaringType() = c and
  startBit = 8 * result.getByteOffset() and
  endBit = 8 * result.getType().getSize() + startBit
  or
  exists(Field f, Class cInner |
    f = c.getAField() and
    cInner = f.getUnderlyingType() and
    result = getAField(cInner, startBit - 8 * f.getByteOffset(), endBit - 8 * f.getByteOffset())
  )
}

private newtype TContent =
  TFieldContent(Class c, int startBit, int endBit) { exists(getAField(c, startBit, endBit)) } or
  TCollectionContent() or
  TArrayContent()

/**
 * A reference contained in an object. Examples include instance fields, the
 * contents of a collection object, or the contents of an array.
 */
class Content extends TContent {
  /** Gets a textual representation of this element. */
  abstract string toString();

  predicate hasLocationInfo(string path, int sl, int sc, int el, int ec) {
    path = "" and sl = 0 and sc = 0 and el = 0 and ec = 0
  }
}

private class FieldContent extends Content, TFieldContent {
  Class c;
  int startBit;
  int endBit;

  FieldContent() { this = TFieldContent(c, startBit, endBit) }

  // Ensure that there's just 1 result for `toString`.
  override string toString() { result = min(Field f | f = getAField() | f.toString()) }

  predicate hasOffset(Class cl, int start, int end) { cl = c and start = startBit and end = endBit }

  Field getAField() { result = getAField(c, startBit, endBit) }
}

private class CollectionContent extends Content, TCollectionContent {
  override string toString() { result = "collection" }
}

private class ArrayContent extends Content, TArrayContent {
  ArrayContent() { this = TArrayContent() }

  override string toString() { result = "array content" }
}

private predicate fieldStoreStepNoChi(Node node1, FieldContent f, PostUpdateNode node2) {
  exists(StoreInstruction store, Class c |
    store = node2.asInstruction() and
    store.getSourceValue() = node1.asInstruction() and
    getWrittenField(store, f.(FieldContent).getAField(), c) and
    f.hasOffset(c, _, _)
  )
}

pragma[noinline]
private predicate getWrittenField(StoreInstruction store, Field f, Class c) {
  exists(FieldAddressInstruction fa |
    fa = store.getDestinationAddress() and
    f = fa.getField() and
    c = f.getDeclaringType()
  )
}

private predicate fieldStoreStepChi(Node node1, FieldContent f, PostUpdateNode node2) {
  exists(StoreInstruction store, ChiInstruction chi |
    node1.asInstruction() = store and
    node2.asInstruction() = chi and
    chi.getPartial() = store and
    exists(Class c |
      c = chi.getResultType() and
      exists(int startBit, int endBit |
        chi.getUpdatedInterval(startBit, endBit) and
        f.hasOffset(c, startBit, endBit)
      )
      or
      getWrittenField(store, f.getAField(), c) and
      f.hasOffset(c, _, _)
    )
  )
}

private predicate arrayStoreStepChi(Node node1, ArrayContent a, PostUpdateNode node2) {
  a = TArrayContent() and
  exists(StoreInstruction store |
    node1.asInstruction() = store and
    (
      // `x[i] = taint()`
      // This matches the characteristic predicate in `ArrayStoreNode`.
      store.getDestinationAddress() instanceof PointerAddInstruction
      or
      // `*p = taint()`
      // This matches the characteristic predicate in `PointerStoreNode`.
      store.getDestinationAddress().(CopyValueInstruction).getUnary() instanceof LoadInstruction
    ) and
    // This `ChiInstruction` will always have a non-conflated result because both `ArrayStoreNode`
    // and `PointerStoreNode` require it in their characteristic predicates.
    node2.asInstruction().(ChiInstruction).getPartial() = store
  )
}

/**
 * Holds if data can flow from `node1` to `node2` via an assignment to `f`.
 * Thus, `node2` references an object with a field `f` that contains the
 * value of `node1`.
 */
predicate storeStep(Node node1, Content f, PostUpdateNode node2) {
  fieldStoreStepNoChi(node1, f, node2) or
  fieldStoreStepChi(node1, f, node2) or
  arrayStoreStepChi(node1, f, node2)
}

bindingset[result, i]
private int unbindInt(int i) { i <= result and i >= result }

pragma[noinline]
private predicate getLoadedField(LoadInstruction load, Field f, Class c) {
  exists(FieldAddressInstruction fa |
    fa = load.getSourceAddress() and
    f = fa.getField() and
    c = f.getDeclaringType()
  )
}

/**
 * Holds if data can flow from `node1` to `node2` via a read of `f`.
 * Thus, `node1` references an object with a field `f` whose value ends up in
 * `node2`.
 */
private predicate fieldReadStep(Node node1, FieldContent f, Node node2) {
  exists(LoadInstruction load |
    node2.asInstruction() = load and
    node1.asInstruction() = load.getSourceValueOperand().getAnyDef() and
    exists(Class c |
      c = load.getSourceValueOperand().getAnyDef().getResultType() and
      exists(int startBit, int endBit |
        load.getSourceValueOperand().getUsedInterval(unbindInt(startBit), unbindInt(endBit)) and
        f.hasOffset(c, startBit, endBit)
      )
      or
      getLoadedField(load, f.getAField(), c) and
      f.hasOffset(c, _, _)
    )
  )
}

private predicate arrayReadStep(Node node1, ArrayContent a, Node node2) {
  a = TArrayContent() and
  exists(LoadInstruction load |
    node1.asInstruction() = load.getSourceValueOperand().getAnyDef() and
    load = node2.asInstruction()
  )
}

/**
 * Holds if data can flow from `node1` to `node2` via a read of `f`.
 * Thus, `node1` references an object with a field `f` whose value ends up in
 * `node2`.
 */
predicate readStep(Node node1, Content f, Node node2) {
  fieldReadStep(node1, f, node2) or
  arrayReadStep(node1, f, node2)
}

/**
 * Holds if values stored inside content `c` are cleared at node `n`.
 */
predicate clearsContent(Node n, Content c) {
  none() // stub implementation
}

/** Gets the type of `n` used for type pruning. */
IRType getNodeType(Node n) {
  suppressUnusedNode(n) and
  result instanceof IRVoidType // stub implementation
}

/** Gets a string representation of a type returned by `getNodeType`. */
string ppReprType(IRType t) { none() } // stub implementation

/**
 * Holds if `t1` and `t2` are compatible, that is, whether data can flow from
 * a node of type `t1` to a node of type `t2`.
 */
pragma[inline]
predicate compatibleTypes(IRType t1, IRType t2) {
  any() // stub implementation
}

private predicate suppressUnusedNode(Node n) { any() }

//////////////////////////////////////////////////////////////////////////////
// Java QL library compatibility wrappers
//////////////////////////////////////////////////////////////////////////////
/** A node that performs a type cast. */
class CastNode extends InstructionNode {
  CastNode() { none() } // stub implementation
}

/**
 * A function that may contain code or a variable that may contain itself. When
 * flow crosses from one _enclosing callable_ to another, the interprocedural
 * data-flow library discards call contexts and inserts a node in the big-step
 * relation used for human-readable path explanations.
 */
class DataFlowCallable = Declaration;

class DataFlowExpr = Expr;

class DataFlowType = IRType;

/** A function call relevant for data flow. */
class DataFlowCall extends CallInstruction {
  /**
   * Gets the nth argument for this call.
   *
   * The range of `n` is from `0` to `getNumberOfArguments() - 1`.
   */
  Node getArgument(int n) { result.asInstruction() = this.getPositionalArgument(n) }

  Function getEnclosingCallable() { result = this.getEnclosingFunction() }
}

predicate isUnreachableInCall(Node n, DataFlowCall call) { none() } // stub implementation

int accessPathLimit() { result = 5 }

/**
 * Holds if `n` does not require a `PostUpdateNode` as it either cannot be
 * modified or its modification cannot be observed, for example if it is a
 * freshly created object that is not saved in a variable.
 *
 * This predicate is only used for consistency checks.
 */
predicate isImmutableOrUnobservable(Node n) {
  // The rules for whether an IR argument gets a post-update node are too
  // complex to model here.
  any()
}

/** Holds if `n` should be hidden from path explanations. */
predicate nodeIsHidden(Node n) { n instanceof OperandNode }
