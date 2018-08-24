import cpp
private import InstructionTag
private import Opcode
private import TempVariableTag
private import TranslatedCondition
private import TranslatedElement
private import TranslatedFunction
private import TranslatedInitialization

/**
 * Gets the TranslatedExpr for the specified expression. If `expr` is a load,
 * the result is the TranslatedExpr for the load portion.
 */
TranslatedExpr getTranslatedExpr(Expr expr) {
  result.getExpr() = expr and
  result.producesExprResult()
}

/**
 * The IR translation of some part of an expression. 
 * A single `Expr` may consist of multiple `TranslatedExpr` objects. Every
 * `Expr` has a single `TranslatedCoreExpr`, which produces the result of the
 * expression before any implicit lvalue-to-rvalue conversion. Any expression
 * with an lvalue-to-rvalue conversion will also have a `TranslatedLoad` to
 * perform that conversion on the original result. A few expressions have
 * additional `TranslatedExpr` objects that compute intermediate values, such
 * as the `TranslatedAllocatorCall` and `TranslatedAllocationSize` within the
 * translation of a `NewExpr`.
 */
abstract class TranslatedExpr extends TranslatedElement {
  Expr expr;

  /**
   * Gets the instruction that produces the result of the expression.
   */
  abstract Instruction getResult();

  /**
   * Holds if this `TranslatedExpr` produces the final result of the original
   * expression from the AST.
   *
   * For example, in `y = x;`, the TranslatedLoad for the VariableAccess `x`
   * produces the result of that VariableAccess expression, but the
   * TranslatedVariableAccess for `x` does not. The TranslatedVariableAccess
   * for `y` does produce its result, however, because there is no load on `y`.
   */
  abstract predicate producesExprResult();

  /**
   * Gets the type of the result produced by this expression.
   */
  final Type getResultType() {
    result = expr.getType().getUnspecifiedType()
  }

  override final Locatable getAST() {
    result = expr
  }

  override final Function getFunction() {
    result = expr.getEnclosingFunction()
  }

  /**
   * Gets the expression from which this `TranslatedExpr` is generated.
   */
  final Expr getExpr() {
    result = expr
  }

  /**
   * Gets the `TranslatedFunction` containing this expression.
   */
  final TranslatedFunction getEnclosingFunction() {
    result = getTranslatedFunction(expr.getEnclosingFunction())
  }
}

/**
 * The IR translation of the "core"  part of an expression. This is the part of
 * the expression that produces the result value of the expression, before any
 * lvalue-to-rvalue conversion on the result. Every expression has a single
 * `TranslatedCoreExpr`.
 */
abstract class TranslatedCoreExpr extends TranslatedExpr {
  override final string toString() {
    result = expr.toString()
  }

  override final predicate producesExprResult() {
    // If there's no load, then this is the only TranslatedExpr for this
    // expression.
    not expr.hasLValueToRValueConversion() or
    // If we're supposed to ignore the load on this expression, then this
    // is the only TranslatedExpr.
    ignoreLoad(expr)
  }

  /**
   * Returns `true` if the result of this `TranslatedExpr` is a glvalue, or
   * `false` if the result is a prvalue.
   *
   * This predicate returns a `boolean` value instead of just a being a plain
   * predicate because all of the subclass predicates that call it require a
   * `boolean` value.
   */
  final boolean isResultGLValue() {
    if(
      expr.isGLValueCategory() or
      // If this TranslatedExpr doesn't produce the result, then it must represent
      // a glvalue that is then loaded by a TranslatedLoad.
      not producesExprResult()
    ) then
      result = true
    else
      result = false
  }
}

class TranslatedConditionValue extends TranslatedCoreExpr, ConditionContext,
  TTranslatedConditionValue {
  TranslatedConditionValue() {
    this = TTranslatedConditionValue(expr)
  }

  override TranslatedElement getChild(int id) {
    id = 0 and result = getCondition()
  }

  override Instruction getFirstInstruction() {
    result = getCondition().getFirstInstruction()
  }

  override predicate hasInstruction(Opcode opcode, InstructionTag tag,
    Type resultType, boolean isGLValue) {
    (
      (
        tag = ConditionValueTrueTempAddressTag() or
        tag = ConditionValueFalseTempAddressTag() or
        tag = ConditionValueResultTempAddressTag()
      ) and
      opcode instanceof Opcode::VariableAddress and
      resultType = getResultType() and
      isGLValue = true
    ) or
    (
      (
        tag = ConditionValueTrueConstantTag() or
        tag = ConditionValueFalseConstantTag()
      ) and
      opcode instanceof Opcode::Constant and
      resultType = getResultType() and
      isGLValue = isResultGLValue()
    ) or
    (
      (
        tag = ConditionValueTrueStoreTag() or
        tag = ConditionValueFalseStoreTag()
      ) and
      opcode instanceof Opcode::Store and
      resultType = getResultType() and
      isGLValue = isResultGLValue()
    ) or
    (
      tag = ConditionValueResultLoadTag() and
      opcode instanceof Opcode::Load and
      resultType = getResultType() and
      isGLValue = isResultGLValue()
    )
  }

  override Instruction getInstructionSuccessor(InstructionTag tag,
    EdgeKind kind) {
    kind instanceof GotoEdge and
    (
      (
        tag = ConditionValueTrueTempAddressTag() and
        result = getInstruction(ConditionValueTrueConstantTag())
      ) or
      (
        tag = ConditionValueTrueConstantTag() and
        result = getInstruction(ConditionValueTrueStoreTag())
      ) or
      (
        tag = ConditionValueTrueStoreTag() and
        result = getInstruction(ConditionValueResultTempAddressTag())
      ) or
      (
        tag = ConditionValueFalseTempAddressTag() and
        result = getInstruction(ConditionValueFalseConstantTag())
      ) or
      (
        tag = ConditionValueFalseConstantTag() and
        result = getInstruction(ConditionValueFalseStoreTag())
      ) or
      (
        tag = ConditionValueFalseStoreTag() and
        result = getInstruction(ConditionValueResultTempAddressTag())
      ) or
      (
        tag = ConditionValueResultTempAddressTag() and
        result = getInstruction(ConditionValueResultLoadTag())
      ) or
      (
        tag = ConditionValueResultLoadTag() and
        result = getParent().getChildSuccessor(this)
      )
    )
  }

  override Instruction getInstructionOperand(InstructionTag tag,
    OperandTag operandTag) {
    (
      tag = ConditionValueTrueStoreTag() and
      (
        (
          operandTag instanceof LoadStoreAddressOperand and
          result = getInstruction(ConditionValueTrueTempAddressTag())
        ) or
        (
          operandTag instanceof CopySourceOperand and
          result = getInstruction(ConditionValueTrueConstantTag())
        )
      )
    ) or
    (
      tag = ConditionValueFalseStoreTag() and
      (
        (
          operandTag instanceof LoadStoreAddressOperand and
          result = getInstruction(ConditionValueFalseTempAddressTag())
        ) or
        (
          operandTag instanceof CopySourceOperand and
          result = getInstruction(ConditionValueFalseConstantTag())
        )
      )
    ) or
    (
      tag = ConditionValueResultLoadTag() and
      (
        (
          operandTag instanceof LoadStoreAddressOperand and
          result = getInstruction(ConditionValueResultTempAddressTag())
        ) or
        (
          operandTag instanceof CopySourceOperand and
          result = getEnclosingFunction().getUnmodeledDefinitionInstruction()
        )
      )
    )
  }

  override predicate hasTempVariable(TempVariableTag tag, Type type) {
    tag = ConditionValueTempVar() and
    type = getResultType()
  }

  override IRVariable getInstructionVariable(InstructionTag tag) {
    (
      tag = ConditionValueTrueTempAddressTag() or
      tag = ConditionValueFalseTempAddressTag() or
      tag = ConditionValueResultTempAddressTag()
    ) and
    result = getTempVariable(ConditionValueTempVar())
  }

  override string getInstructionConstantValue(InstructionTag tag) {
    tag = ConditionValueTrueConstantTag() and result = "1" or
    tag = ConditionValueFalseConstantTag() and result = "0"
  }

  override Instruction getResult() {
    result = getInstruction(ConditionValueResultLoadTag())
  }

  override Instruction getChildSuccessor(TranslatedElement child) {
    none()
  }

  override Instruction getChildTrueSuccessor(TranslatedCondition child) {
    child = getCondition() and
    result = getInstruction(ConditionValueTrueTempAddressTag())
  }

  override Instruction getChildFalseSuccessor(TranslatedCondition child) {
    child = getCondition() and
    result = getInstruction(ConditionValueFalseTempAddressTag())
  }
  
  private TranslatedCondition getCondition() {
    result = getTranslatedCondition(expr)
  }
}

/**
 * IR translation of an implicit lvalue-to-rvalue conversion on the result of
 * an expression.
 */
class TranslatedLoad extends TranslatedExpr, TTranslatedLoad {
  TranslatedLoad() {
    this = TTranslatedLoad(expr)
  }

  override string toString() {
    result = "Load of " + expr.toString()
  }

  override Instruction getFirstInstruction() {
    result = getOperand().getFirstInstruction()
  }

  override TranslatedElement getChild(int id) {
    id = 0 and result = getOperand()
  }

  override predicate hasInstruction(Opcode opcode, InstructionTag tag,
    Type resultType, boolean isGLValue) {
    tag = LoadTag() and
    opcode instanceof Opcode::Load and
    resultType = expr.getType().getUnspecifiedType() and
    if expr.isGLValueCategory() then
      isGLValue = true
    else
      isGLValue = false
  }

  override Instruction getInstructionSuccessor(InstructionTag tag,
    EdgeKind kind) {
    tag = LoadTag() and
    result = getParent().getChildSuccessor(this) and
    kind instanceof GotoEdge
  }

  override Instruction getChildSuccessor(TranslatedElement child) {
    child = getOperand() and result = getInstruction(LoadTag())
  }

  override Instruction getResult() {
    result = getInstruction(LoadTag())
  }

  override Instruction getInstructionOperand(InstructionTag tag,
      OperandTag operandTag) {
    tag = LoadTag() and
    (
      (
        operandTag instanceof LoadStoreAddressOperand and
        result = getOperand().getResult()
      ) or
      (
        operandTag instanceof CopySourceOperand and
        result = getEnclosingFunction().getUnmodeledDefinitionInstruction()
      )
    )
  }

  override final predicate producesExprResult() {
    // A load always produces the result of the expression.
    any()
  }

  private TranslatedCoreExpr getOperand() {
    result.getExpr() = expr
  }
}

class TranslatedCommaExpr extends TranslatedNonConstantExpr {
  CommaExpr comma;

  TranslatedCommaExpr() {
    comma = expr
  }

  override Instruction getFirstInstruction() {
    result = getLeftOperand().getFirstInstruction()
  }

  override TranslatedElement getChild(int id) {
    id = 0 and result = getLeftOperand() or
    id = 1 and result = getRightOperand()
  }

  override Instruction getResult() {
    result = getRightOperand().getResult()
  }

  override Instruction getInstructionSuccessor(InstructionTag tag,
    EdgeKind kind) {
    none()
  }

  override Instruction getChildSuccessor(TranslatedElement child) {
    (
      child = getLeftOperand() and
      result = getRightOperand().getFirstInstruction()
    ) or
    child = getRightOperand() and result = getParent().getChildSuccessor(this)
  }

  override predicate hasInstruction(Opcode opcode, InstructionTag tag,
    Type resultType, boolean isGLValue) {
    none()
  }

  override Instruction getInstructionOperand(InstructionTag tag,
    OperandTag operandTag) {
    none()
  }

  private TranslatedExpr getLeftOperand() {
    result = getTranslatedExpr(comma.getLeftOperand().getFullyConverted())
  }

  private TranslatedExpr getRightOperand() {
    result = getTranslatedExpr(comma.getRightOperand().getFullyConverted())
  }
}

abstract class TranslatedCrementOperation extends TranslatedNonConstantExpr {
  CrementOperation op;

  TranslatedCrementOperation() {
    op = expr
  }

  override final TranslatedElement getChild(int id) {
    id = 0 and result = getOperand()
  }

  override final string getInstructionConstantValue(InstructionTag tag) {
    tag = CrementConstantTag() and
    exists(Type resultType |
      resultType = getResultType() and
      (
        resultType instanceof IntegralType and result = "1" or
        resultType instanceof FloatingPointType and result = "1.0" or
        resultType instanceof PointerType and result = "1"
      )
    )
  }

  private Type getConstantType() {
    exists(Type resultType |
      resultType = getResultType() and
      (
        resultType instanceof ArithmeticType and result = resultType or
        resultType instanceof PointerType and result = getIntType()
      )
    )
  }

  override final predicate hasInstruction(Opcode opcode, InstructionTag tag,
    Type resultType, boolean isGLValue) {
    isGLValue = false and
    (
      (
        tag = CrementLoadTag() and
        opcode instanceof Opcode::Load and
        resultType = getResultType()
      ) or
      (
        tag = CrementConstantTag() and
        opcode instanceof Opcode::Constant and
        resultType = getConstantType()
      ) or
      (
        tag = CrementOpTag() and
        opcode = getOpcode() and
        resultType = getResultType()
      ) or
      (
        tag = CrementStoreTag() and
        opcode instanceof Opcode::Store and
        resultType = getResultType()
      )
    )
  }

  override final Instruction getInstructionOperand(InstructionTag tag,
    OperandTag operandTag) {
    (
      tag = CrementLoadTag() and
      (
        (
          operandTag instanceof LoadStoreAddressOperand and
          result = getOperand().getResult()
        ) or
        (
          operandTag instanceof CopySourceOperand and
          result = getEnclosingFunction().getUnmodeledDefinitionInstruction()
        )
      )
    ) or
    (
      tag = CrementOpTag() and
      (
        (
          operandTag instanceof LeftOperand and
          result = getInstruction(CrementLoadTag())
        ) or
        (
          operandTag instanceof RightOperand and
          result = getInstruction(CrementConstantTag())
        )
      )
    ) or
    (
      tag = CrementStoreTag() and
      (
        (
          operandTag instanceof LoadStoreAddressOperand and
          result = getOperand().getResult()
        ) or
        (
          operandTag instanceof CopySourceOperand and
          result = getInstruction(CrementOpTag())
        )
      )
    )
  }

  override final Instruction getFirstInstruction() {
    result = getOperand().getFirstInstruction()
  }

  override final Instruction getInstructionSuccessor(InstructionTag tag,
    EdgeKind kind) {
    kind instanceof GotoEdge and
    (
      (
        tag = CrementLoadTag() and
        result = getInstruction(CrementConstantTag())
      ) or
      (
        tag = CrementConstantTag() and
        result = getInstruction(CrementOpTag())
      ) or
      (
        tag = CrementOpTag() and
        result = getInstruction(CrementStoreTag())
      ) or
      (
        tag = CrementStoreTag() and
        result = getParent().getChildSuccessor(this)
      )
    )
  }

  override final Instruction getChildSuccessor(TranslatedElement child) {
    child = getOperand() and result = getInstruction(CrementLoadTag())
  }

  override final int getInstructionElementSize(InstructionTag tag) {
    tag = CrementOpTag() and
    (
      getOpcode() instanceof Opcode::PointerAdd or
      getOpcode() instanceof Opcode::PointerSub
    ) and
    result = max(getResultType().(PointerType).getBaseType().getSize())
  }

  final TranslatedExpr getOperand() {
    result = getTranslatedExpr(op.getOperand().getFullyConverted())
  }

  final Opcode getOpcode() {
    exists(Type resultType |
      resultType = getResultType() and
      (
        (
          op instanceof IncrementOperation and
          if resultType instanceof PointerType then
            result instanceof Opcode::PointerAdd
          else
            result instanceof Opcode::Add
        ) or
        (
          op instanceof DecrementOperation and
          if resultType instanceof PointerType then
            result instanceof Opcode::PointerSub
          else
            result instanceof Opcode::Sub
        )
      )
    )
  }
}

class TranslatedPrefixCrementOperation extends TranslatedCrementOperation {
  TranslatedPrefixCrementOperation() {
    op instanceof PrefixCrementOperation
  }

  override Instruction getResult() {
    if expr.isPRValueCategory() then (
      // If this is C, then the result of a prefix crement is a prvalue for the
      // new value assigned to the operand. If this is C++, then the result is
      // an lvalue, but that lvalue is being loaded as part of this expression.
      // EDG doesn't mark this as a load.
      result = getInstruction(CrementOpTag())
    )
    else (
      // This is C++, where the result is an lvalue for the operand, and that
      // lvalue is not being loaded as part of this expression.
      result = getOperand().getResult()
    )
  }
}

class TranslatedPostfixCrementOperation extends TranslatedCrementOperation {
  TranslatedPostfixCrementOperation() {
    op instanceof PostfixCrementOperation
  }

  override Instruction getResult() {
    // The result is a prvalue copy of the original value
    result = getInstruction(CrementLoadTag())
  }
}

class TranslatedArrayExpr extends TranslatedNonConstantExpr {
  ArrayExpr arrayExpr;

  TranslatedArrayExpr() {
    arrayExpr = expr
  }

  override Instruction getFirstInstruction() {
    result = getBaseOperand().getFirstInstruction()
  }

  override final TranslatedElement getChild(int id) {
    id = 0 and result = getBaseOperand() or
    id = 1 and result = getOffsetOperand()
  }

  override Instruction getInstructionSuccessor(InstructionTag tag,
    EdgeKind kind) {
    tag = OnlyInstructionTag() and
    result = getParent().getChildSuccessor(this) and
    kind instanceof GotoEdge
  }

  override Instruction getChildSuccessor(TranslatedElement child) {
    (
      child = getBaseOperand() and
      result = getOffsetOperand().getFirstInstruction()
    ) or
    (
      child = getOffsetOperand() and
      result = getInstruction(OnlyInstructionTag())
    )
  }

  override Instruction getResult() {
    result = getInstruction(OnlyInstructionTag())
  }

  override predicate hasInstruction(Opcode opcode, InstructionTag tag,
    Type resultType, boolean isGLValue) {
    tag = OnlyInstructionTag() and
    opcode instanceof Opcode::PointerAdd and
    resultType = getBaseOperand().getResultType() and
    isGLValue = false
  }

  override Instruction getInstructionOperand(InstructionTag tag,
    OperandTag operandTag) {
    tag = OnlyInstructionTag() and
    (
      (
        operandTag instanceof LeftOperand and
        result = getBaseOperand().getResult()
      ) or
      (
        operandTag instanceof RightOperand and
        result = getOffsetOperand().getResult()
      )
    )
  }

  override int getInstructionElementSize(InstructionTag tag) {
    tag = OnlyInstructionTag() and
    result = max(getBaseOperand().getResultType().(PointerType).getBaseType().getSize())
  }

  private TranslatedExpr getBaseOperand() {
    result = getTranslatedExpr(arrayExpr.getArrayBase().getFullyConverted())
  }

  private TranslatedExpr getOffsetOperand() {
    result = getTranslatedExpr(arrayExpr.getArrayOffset().getFullyConverted())
  }
}

abstract class TranslatedTransparentExpr extends TranslatedNonConstantExpr {
  override final Instruction getFirstInstruction() {
    result = getOperand().getFirstInstruction()
  }

  override final TranslatedElement getChild(int id) {
    id = 0 and result = getOperand()
  }

  override final Instruction getInstructionSuccessor(InstructionTag tag,
    EdgeKind kind) {
    none()
  }

  override final Instruction getChildSuccessor(TranslatedElement child) {
    child = getOperand() and result = getParent().getChildSuccessor(this)
  }

  override final predicate hasInstruction(Opcode opcode, InstructionTag tag,
    Type resultType, boolean isGLValue) {
    none()
  }

  override final Instruction getResult() {
    result = getOperand().getResult()
  }

  override final Instruction getInstructionOperand(InstructionTag tag,
    OperandTag operandTag) {
    none()
  }

  abstract TranslatedExpr getOperand();
}

class TranslatedTransparentUnaryOperation extends TranslatedTransparentExpr {
  UnaryOperation op;

  TranslatedTransparentUnaryOperation() {
    op = expr and
    (
      // *p is the same as p until the result is loaded.
      expr instanceof PointerDereferenceExpr or
      // &x is the same as x. &x isn't loadable, but is included
      // here to avoid having two nearly identical classes.
      expr instanceof AddressOfExpr
    )
  }

  override TranslatedExpr getOperand() {
    result = getTranslatedExpr(op.getOperand().getFullyConverted())
  }
}

class TranslatedTransparentConversion extends TranslatedTransparentExpr {
  Conversion conv;

  TranslatedTransparentConversion() {
    conv = expr and
    (
      conv instanceof ParenthesisExpr or
      conv instanceof ReferenceDereferenceExpr or
      conv instanceof ReferenceToExpr
    )
  }

  override TranslatedExpr getOperand() {
    result = getTranslatedExpr(conv.getExpr())
  }
}

class TranslatedThisExpr extends TranslatedNonConstantExpr {
  TranslatedThisExpr() {
    expr instanceof ThisExpr
  }

  override final TranslatedElement getChild(int id) {
    none()
  }

  override final predicate hasInstruction(Opcode opcode, InstructionTag tag,
    Type resultType, boolean isGLValue) {
    tag = OnlyInstructionTag() and
    opcode instanceof Opcode::CopyValue and
    resultType = expr.getType().getUnspecifiedType() and
    isGLValue = false
  }

  override final Instruction getResult() {
    result = getInstruction(OnlyInstructionTag())
  }

  override final Instruction getFirstInstruction() {
    result = getInstruction(OnlyInstructionTag())
  }

  override final Instruction getInstructionSuccessor(InstructionTag tag,
    EdgeKind kind) {
    kind instanceof GotoEdge and
    tag = OnlyInstructionTag() and
    result = getParent().getChildSuccessor(this)
  }

  override final Instruction getChildSuccessor(TranslatedElement child) {
    none()
  }

  override final Instruction getInstructionOperand(InstructionTag tag,
    OperandTag operandTag) {
    tag = OnlyInstructionTag() and
    operandTag instanceof CopySourceOperand and
    result = getInitializeThisInstruction()
  }

  private Instruction getInitializeThisInstruction() {
    result = getTranslatedFunction(expr.getEnclosingFunction()).getInitializeThisInstruction()
  }
}

abstract class TranslatedVariableAccess extends TranslatedNonConstantExpr {
  VariableAccess access;

  TranslatedVariableAccess() {
    access = expr
  }

  override final TranslatedElement getChild(int id) {
    id = 0 and result = getQualifier()  // Might not exist
  }

  final TranslatedExpr getQualifier() {
    result = getTranslatedExpr(access.getQualifier().getFullyConverted())
  }

  override Instruction getResult() {
    result = getInstruction(OnlyInstructionTag())
  }

  override final Instruction getInstructionSuccessor(InstructionTag tag,
    EdgeKind kind) {
    tag = OnlyInstructionTag() and
    result = getParent().getChildSuccessor(this) and
    kind instanceof GotoEdge
  }

  override final Instruction getChildSuccessor(TranslatedElement child) {
    child = getQualifier() and result = getInstruction(OnlyInstructionTag())
  }
}

class TranslatedNonFieldVariableAccess extends TranslatedVariableAccess {
  TranslatedNonFieldVariableAccess() {
    not expr instanceof FieldAccess
  }

  override Instruction getFirstInstruction() {
    if exists(getQualifier()) then
      result = getQualifier().getFirstInstruction()
    else
      result = getInstruction(OnlyInstructionTag())
  }

  override Instruction getInstructionOperand(InstructionTag tag,
    OperandTag operandTag) {
    none()
  }

  override predicate hasInstruction(Opcode opcode, InstructionTag tag,
    Type resultType, boolean isGLValue) {
    tag = OnlyInstructionTag() and
    opcode instanceof Opcode::VariableAddress and
    resultType = getResultType() and
    isGLValue = true
  }

  override IRVariable getInstructionVariable(InstructionTag tag) {
    tag = OnlyInstructionTag() and
    result = getIRUserVariable(access.getEnclosingFunction(), 
      access.getTarget())
  }
}

class TranslatedFieldAccess extends TranslatedVariableAccess {
  FieldAccess fieldAccess;

  TranslatedFieldAccess() {
    //REVIEW: Implicit 'this'?
    fieldAccess = access
  }

  override Instruction getFirstInstruction() {
    result = getQualifier().getFirstInstruction()
  }

  override Instruction getInstructionOperand(InstructionTag tag,
    OperandTag operandTag) {
    tag = OnlyInstructionTag() and
    operandTag instanceof UnaryOperand and
    result = getQualifier().getResult()
  }

  override predicate hasInstruction(Opcode opcode, InstructionTag tag,
    Type resultType, boolean isGLValue) {
    tag = OnlyInstructionTag() and
    opcode instanceof Opcode::FieldAddress and
    resultType = getResultType() and
    isGLValue = true
  }

  override Field getInstructionField(InstructionTag tag) {
    tag = OnlyInstructionTag() and
    result = access.getTarget()
  }
}

class TranslatedFunctionAccess extends TranslatedNonConstantExpr {
  FunctionAccess access;

  TranslatedFunctionAccess() {
    access = expr
  }

  override TranslatedElement getChild(int id) {
    none()
  }

  override Instruction getFirstInstruction() {
    result = getInstruction(OnlyInstructionTag())
  }

  override Instruction getResult() {
    result = getInstruction(OnlyInstructionTag())
  }

  override final Instruction getInstructionSuccessor(InstructionTag tag,
    EdgeKind kind) {
    tag = OnlyInstructionTag() and
    result = getParent().getChildSuccessor(this) and
    kind instanceof GotoEdge
  }

  override predicate hasInstruction(Opcode opcode, InstructionTag tag,
    Type resultType, boolean isGLValue) {
    tag = OnlyInstructionTag() and
    opcode instanceof Opcode::FunctionAddress and
    resultType = access.getType().getUnspecifiedType() and
    isGLValue = true
  }

  override Function getInstructionFunction(InstructionTag tag) {
    tag = OnlyInstructionTag() and
    result = access.getTarget()
  }

  override Instruction getChildSuccessor(TranslatedElement child) {
    none()
  }
}

/**
 * IR translation of an expression whose value is not known at compile time.
 */
abstract class TranslatedNonConstantExpr extends TranslatedCoreExpr {
  TranslatedNonConstantExpr() {
    this = TTranslatedValueExpr(expr) and
    not expr.isConstant()
  }
}

/**
 * IR translation of an expression with a compile-time constant value. This
 * includes not only literals, but also "integral constant expressions" (e.g.
 * `1 + 2`).
 */
abstract class TranslatedConstantExpr extends TranslatedCoreExpr {
  TranslatedConstantExpr() {
    this = TTranslatedValueExpr(expr) and
    expr.isConstant()
  }

  override final Instruction getFirstInstruction() {
    result = getInstruction(OnlyInstructionTag())
  }

  override final TranslatedElement getChild(int id) {
    none()
  }

  override final Instruction getResult() {
    result = getInstruction(OnlyInstructionTag())
  }

  override final Instruction getInstructionOperand(InstructionTag tag,
    OperandTag operandTag) {
    none()
  }

  override final predicate hasInstruction(Opcode opcode, InstructionTag tag,
    Type resultType, boolean isGLValue) {
    tag = OnlyInstructionTag() and
    opcode = getOpcode() and
    resultType = getResultType() and
    if(expr.isGLValueCategory() or expr.hasLValueToRValueConversion()) then
      isGLValue = true
    else
      isGLValue = false
  }

  override final Instruction getInstructionSuccessor(InstructionTag tag,
    EdgeKind kind) {
    tag = OnlyInstructionTag() and
    result = getParent().getChildSuccessor(this) and
    kind instanceof GotoEdge
  }

  override final Instruction getChildSuccessor(TranslatedElement child) {
    none()
  }

  abstract Opcode getOpcode();
}

class TranslatedArithmeticLiteral extends TranslatedConstantExpr {
  TranslatedArithmeticLiteral() {
    not expr instanceof StringLiteral
  }

  override string getInstructionConstantValue(InstructionTag tag) {
    tag = OnlyInstructionTag() and
    result = expr.getValue()
  }

  override Opcode getOpcode() {
    result instanceof Opcode::Constant
  }
}

class TranslatedStringLiteral extends TranslatedConstantExpr {
  StringLiteral stringLiteral;

  TranslatedStringLiteral() {
    stringLiteral = expr
  }

  override StringLiteral getInstructionStringLiteral(InstructionTag tag) {
    tag = OnlyInstructionTag() and
    result = stringLiteral
  }

  override Opcode getOpcode() {
    result instanceof Opcode::StringConstant
  }
}

/**
 * IR translation of an expression that performs a single operation on its
 * operands and returns the result.
 */
abstract class TranslatedSingleInstructionExpr extends
    TranslatedNonConstantExpr {
  /**
   * Gets the `Opcode` of the operation to be performed.
   */
  abstract Opcode getOpcode();

  override final predicate hasInstruction(Opcode opcode, InstructionTag tag,
    Type resultType, boolean isGLValue) {
    opcode = getOpcode() and
    tag = OnlyInstructionTag() and
    resultType = getResultType() and
    isGLValue = isResultGLValue()
  }

  override final Instruction getResult() {
    result = getInstruction(OnlyInstructionTag())
  }
}

class TranslatedUnaryExpr extends TranslatedSingleInstructionExpr {
  TranslatedUnaryExpr() {
    expr instanceof NotExpr or
    expr instanceof ComplementExpr or
    expr instanceof UnaryPlusExpr or
    expr instanceof UnaryMinusExpr
  }

  override final Instruction getFirstInstruction() {
    result = getOperand().getFirstInstruction()
  }

  override final TranslatedElement getChild(int id) {
    id = 0 and result = getOperand()
  }

  override final Instruction getInstructionSuccessor(InstructionTag tag,
    EdgeKind kind) {
    tag = OnlyInstructionTag() and
    result = getParent().getChildSuccessor(this) and
    kind instanceof GotoEdge
  }

  override final Instruction getChildSuccessor(TranslatedElement child) {
    child = getOperand() and result = getInstruction(OnlyInstructionTag())
  }

  override final Instruction getInstructionOperand(InstructionTag tag,
    OperandTag operandTag) {
    tag = OnlyInstructionTag() and
    result = getOperand().getResult() and
    if getOpcode() instanceof Opcode::CopyValue then
      operandTag instanceof CopySourceOperand
    else
      operandTag instanceof UnaryOperand
  }

  override final Opcode getOpcode() {
    expr instanceof NotExpr and result instanceof Opcode::LogicalNot or
    expr instanceof ComplementExpr and result instanceof Opcode::BitComplement or
    expr instanceof UnaryPlusExpr and result instanceof Opcode::CopyValue or
    expr instanceof UnaryMinusExpr and result instanceof Opcode::Negate
  }

  private TranslatedExpr getOperand() {
    result = getTranslatedExpr(
      expr.(UnaryOperation).getOperand().getFullyConverted()
    )
  }
}

abstract class TranslatedConversion extends TranslatedNonConstantExpr {
  Conversion conv;

  TranslatedConversion() {
    conv = expr
  }

  override Instruction getFirstInstruction() {
    result = getOperand().getFirstInstruction()
  }

  override final TranslatedElement getChild(int id) {
    id = 0 and result = getOperand()
  }

  final TranslatedExpr getOperand() {
    result = getTranslatedExpr(expr.(Conversion).getExpr())
  }
}

/**
 * Represents the translation of a conversion expression that generates a
 * single instruction.
 */
abstract class TranslatedSingleInstructionConversion extends TranslatedConversion {
  override Instruction getInstructionSuccessor(InstructionTag tag,
    EdgeKind kind) {
    tag = OnlyInstructionTag() and
    result = getParent().getChildSuccessor(this) and
    kind instanceof GotoEdge
  }

  override Instruction getChildSuccessor(TranslatedElement child) {
    child = getOperand() and result = getInstruction(OnlyInstructionTag())
  }

  override predicate hasInstruction(Opcode opcode, InstructionTag tag,
    Type resultType, boolean isGLValue) {
    tag = OnlyInstructionTag() and
    opcode = getOpcode() and
    resultType = getResultType() and
    isGLValue = isResultGLValue()
  }

  override Instruction getResult() {
    result = getInstruction(OnlyInstructionTag())
  }

  override Instruction getInstructionOperand(InstructionTag tag,
    OperandTag operandTag) {
    tag = OnlyInstructionTag() and
    operandTag instanceof UnaryOperand and
    result = getOperand().getResult()
  }

  /**
   * Gets the opcode of the generated instruction.
   */
  abstract Opcode getOpcode();
}

/**
 * Represents the translation of a conversion expression that generates a
 * `Convert` instruction.
 */
class TranslatedSimpleConversion extends TranslatedSingleInstructionConversion {
  TranslatedSimpleConversion() {
    conv instanceof ArithmeticConversion or
    conv instanceof PointerConversion or
    conv instanceof PointerToMemberConversion or
    conv instanceof PointerToIntegralConversion or
    conv instanceof IntegralToPointerConversion or
    conv instanceof GlvalueConversion or
    conv instanceof ArrayToPointerConversion or
    conv instanceof PrvalueAdjustmentConversion or
    conv instanceof VoidConversion
  }

  override Opcode getOpcode() {
    result instanceof Opcode::Convert
  }
}

/**
 * Represents the translation of a dynamic_cast expression.
 */
class TranslatedDynamicCast extends TranslatedSingleInstructionConversion {
  TranslatedDynamicCast() {
    conv instanceof DynamicCast
  }

  override Opcode getOpcode() {
    exists(Type resultType |
      resultType = getResultType() and
      if resultType instanceof PointerType then (
        if resultType.(PointerType).getBaseType() instanceof VoidType then
          result instanceof Opcode::DynamicCastToVoid
        else
          result instanceof Opcode::CheckedConvertOrNull
      )
      else
        result instanceof Opcode::CheckedConvertOrThrow
    )
  }
}

/**
 * Represents the translation of a `BaseClassConversion` or `DerivedClassConversion`
 * expression.
 */
class TranslatedInheritanceConversion extends TranslatedSingleInstructionConversion {
  InheritanceConversion inheritanceConv;

  TranslatedInheritanceConversion() {
    inheritanceConv = conv
  }

  override predicate getInstructionInheritance(InstructionTag tag, Class baseClass,
    Class derivedClass) {
    tag = OnlyInstructionTag() and
    baseClass = inheritanceConv.getBaseClass() and
    derivedClass = inheritanceConv.getDerivedClass()
  }

  override Opcode getOpcode() {
    if inheritanceConv instanceof BaseClassConversion then (
      if inheritanceConv.(BaseClassConversion).isVirtual() then
        result instanceof Opcode::ConvertToVirtualBase
      else
        result instanceof Opcode::ConvertToBase
    )
    else
      result instanceof Opcode::ConvertToDerived
  }
}

/**
 * Represents the translation of a `BoolConversion` expression, which generates
 * a comparison with zero.
 */
class TranslatedBoolConversion extends TranslatedConversion {
  TranslatedBoolConversion() {
    conv instanceof BoolConversion
  }

  override Instruction getInstructionSuccessor(InstructionTag tag,
    EdgeKind kind) {
    kind instanceof GotoEdge and
    (
      (
        tag = BoolConversionConstantTag() and
        result = getInstruction(BoolConversionCompareTag())
      ) or
      (
        tag = BoolConversionCompareTag() and
        result = getParent().getChildSuccessor(this)
      )
    )
  }

  override Instruction getChildSuccessor(TranslatedElement child) {
    child = getOperand() and result = getInstruction(BoolConversionConstantTag())
  }

  override predicate hasInstruction(Opcode opcode, InstructionTag tag,
    Type resultType, boolean isGLValue) {
    isGLValue = false and
    (
      (
        tag = BoolConversionConstantTag() and
        opcode instanceof Opcode::Constant and
        resultType = getOperand().getResultType()
      ) or
      (
        tag = BoolConversionCompareTag() and
        opcode instanceof Opcode::CompareNE and
        resultType instanceof BoolType
      )
    )
  }

  override Instruction getResult() {
    result = getInstruction(BoolConversionCompareTag())
  }

  override Instruction getInstructionOperand(InstructionTag tag,
    OperandTag operandTag) {
    tag = BoolConversionCompareTag() and
    (
      (
        operandTag instanceof LeftOperand and
        result = getOperand().getResult()
      ) or
      (
        operandTag instanceof RightOperand and
        result = getInstruction(BoolConversionConstantTag())
      )
    )
  }

  override string getInstructionConstantValue(InstructionTag tag) {
    tag = BoolConversionConstantTag() and
    result = "0"
  }
}

private Opcode binaryBitwiseOpcode(BinaryBitwiseOperation expr) {
  expr instanceof LShiftExpr and result instanceof Opcode::ShiftLeft or
  expr instanceof RShiftExpr and result instanceof Opcode::ShiftRight or
  expr instanceof BitwiseAndExpr and result instanceof Opcode::BitAnd or
  expr instanceof BitwiseOrExpr and result instanceof Opcode::BitOr or
  expr instanceof BitwiseXorExpr and result instanceof Opcode::BitXor
}

private Opcode binaryArithmeticOpcode(BinaryArithmeticOperation expr) {
  expr instanceof AddExpr and result instanceof Opcode::Add or
  expr instanceof SubExpr and result instanceof Opcode::Sub or
  expr instanceof MulExpr and result instanceof Opcode::Mul or
  expr instanceof DivExpr and result instanceof Opcode::Div or
  expr instanceof RemExpr and result instanceof Opcode::Rem or
  expr instanceof PointerAddExpr and result instanceof Opcode::PointerAdd or
  expr instanceof PointerSubExpr and result instanceof Opcode::PointerSub or
  expr instanceof PointerDiffExpr and result instanceof Opcode::PointerDiff
}

private Opcode comparisonOpcode(ComparisonOperation expr) {
  expr instanceof EQExpr and result instanceof Opcode::CompareEQ or
  expr instanceof NEExpr and result instanceof Opcode::CompareNE or
  expr instanceof LTExpr and result instanceof Opcode::CompareLT or
  expr instanceof GTExpr and result instanceof Opcode::CompareGT or
  expr instanceof LEExpr and result instanceof Opcode::CompareLE or
  expr instanceof GEExpr and result instanceof Opcode::CompareGE
}

/**
 * IR translation of a simple binary operation.
 */
class TranslatedBinaryOperation extends TranslatedSingleInstructionExpr {
  TranslatedBinaryOperation() {
    expr instanceof BinaryArithmeticOperation or
    expr instanceof BinaryBitwiseOperation or
    expr instanceof ComparisonOperation
  }

  override Instruction getFirstInstruction() {
    result = getLeftOperand().getFirstInstruction()
  }

  override final TranslatedElement getChild(int id) {
    id = 0 and result = getLeftOperand() or
    id = 1 and result = getRightOperand()
  }

  override final Instruction getInstructionOperand(InstructionTag tag,
    OperandTag operandTag) {
    tag = OnlyInstructionTag() and
    if swapOperandsOnOp() then (
      (
        operandTag instanceof RightOperand and
        result = getLeftOperand().getResult()
      ) or
      (
        operandTag instanceof LeftOperand and
        result = getRightOperand().getResult()
      )
    )
    else (
      (
        operandTag instanceof LeftOperand and
        result = getLeftOperand().getResult()
      ) or
      (
        operandTag instanceof RightOperand and
        result = getRightOperand().getResult()
      )
    )
  }

  override Instruction getInstructionSuccessor(InstructionTag tag,
    EdgeKind kind) {
    tag = OnlyInstructionTag() and
    result = getParent().getChildSuccessor(this) and
    kind instanceof GotoEdge
  }
  
  override Instruction getChildSuccessor(TranslatedElement child) {
    (
      child = getLeftOperand() and
      result = getRightOperand().getFirstInstruction()
    ) or
    (
      child = getRightOperand() and
      result = getInstruction(OnlyInstructionTag())
    )
  }

  override Opcode getOpcode() {
    result = binaryArithmeticOpcode(expr.(BinaryArithmeticOperation)) or
    result = binaryBitwiseOpcode(expr.(BinaryBitwiseOperation)) or
    result = comparisonOpcode(expr.(ComparisonOperation))
  }

  override int getInstructionElementSize(InstructionTag tag) {
    tag = OnlyInstructionTag() and
    exists(Opcode opcode |
      opcode = getOpcode() and
      (
        opcode instanceof Opcode::PointerAdd or opcode instanceof Opcode::PointerSub or opcode instanceof Opcode::PointerDiff
      ) and
      result = max(getPointerOperand().getResultType().(PointerType).getBaseType().getSize())
    )
  }

  private TranslatedExpr getPointerOperand() {
    if swapOperandsOnOp() then
      result = getRightOperand()
    else
      result = getLeftOperand()
  }

  private predicate swapOperandsOnOp() {
    // Swap the operands on a pointer add 'i + p', so that the pointer operand
    // always comes first. Note that we still evaluate the operands
    // left-to-right.
    exists(PointerAddExpr ptrAdd, Type rightType |
      ptrAdd = expr and
      rightType = ptrAdd.getRightOperand().getType().getUnspecifiedType() and
      rightType instanceof PointerType
    )
  }

  private TranslatedExpr getLeftOperand() {
    result = getTranslatedExpr(
      expr.(BinaryOperation).getLeftOperand().getFullyConverted()
    )
  }

  private TranslatedExpr getRightOperand() {
    result = getTranslatedExpr(
      expr.(BinaryOperation).getRightOperand().getFullyConverted()
    )
  }
}

abstract class TranslatedAssignment extends TranslatedNonConstantExpr {
  Assignment assign;

  TranslatedAssignment() {
    expr = assign
  }

  override final TranslatedElement getChild(int id) {
    id = 0 and result = getLeftOperand() or
    id = 1 and result = getRightOperand()
  }

  override final Instruction getFirstInstruction() {
    // Evaluation is right-to-left
    result = getRightOperand().getFirstInstruction()
  }

  override final Instruction getResult() {
    if expr.isPRValueCategory() then (
      // If this is C, then the result of an assignment is a prvalue for the new
      // value assigned to the left operand. If this is C++, then the result is
      // an lvalue, but that lvalue is being loaded as part of this expression.
      // EDG doesn't mark this as a load.
      result = getStoredValue()
    )
    else (
      // This is C++, where the result is an lvalue for the left operand,
      // and that lvalue is not being loaded as part of this expression.
      result = getLeftOperand().getResult()
    )
  }

  abstract Instruction getStoredValue();

  final TranslatedExpr getLeftOperand() {
    result = getTranslatedExpr(
      assign.getLValue().getFullyConverted()
    )
  }

  final TranslatedExpr getRightOperand() {
    result = getTranslatedExpr(
      assign.getRValue().getFullyConverted()
    )
  }
}

class TranslatedAssignExpr extends TranslatedAssignment {
  TranslatedAssignExpr() {
    assign instanceof AssignExpr
  }

  override Instruction getInstructionSuccessor(InstructionTag tag,
    EdgeKind kind) {
    tag = AssignmentStoreTag() and
    result = getParent().getChildSuccessor(this) and
    kind instanceof GotoEdge
  }

  override Instruction getChildSuccessor(TranslatedElement child) {
    // Operands are evaluated right-to-left.
    (
      child = getRightOperand() and
      result = getLeftOperand().getFirstInstruction()
    ) or
    (
      child = getLeftOperand() and
      result = getInstruction(AssignmentStoreTag())
    )
  }

  override predicate hasInstruction(Opcode opcode, InstructionTag tag,
    Type resultType, boolean isGLValue) {
    tag = AssignmentStoreTag() and
    opcode instanceof Opcode::Store and
    resultType = getResultType() and
    isGLValue = false
  }

  override Instruction getInstructionOperand(InstructionTag tag,
    OperandTag operandTag) {
    tag = AssignmentStoreTag() and
    (
      (
        operandTag instanceof LoadStoreAddressOperand and
        result = getLeftOperand().getResult()
      ) or
      (
        operandTag instanceof CopySourceOperand and
        result = getRightOperand().getResult()
      )
    )
  }

  override Instruction getStoredValue() {
    result = getRightOperand().getResult()
  }
}

class TranslatedAssignOperation extends TranslatedAssignment {
  AssignOperation assignOp;

  TranslatedAssignOperation() {
    expr = assignOp
  }

  override Instruction getInstructionSuccessor(InstructionTag tag,
    EdgeKind kind) {
    kind instanceof GotoEdge and
    (
      (
        tag = AssignOperationLoadTag() and
        if leftOperandNeedsConversion() then
          result = getInstruction(AssignOperationConvertLeftTag())
        else
          result = getInstruction(AssignOperationOpTag())
      ) or
      (
        tag = AssignOperationConvertLeftTag() and
        result = getInstruction(AssignOperationOpTag())
      ) or
      (
        tag = AssignOperationOpTag() and
        if leftOperandNeedsConversion() then
          result = getInstruction(AssignOperationConvertResultTag())
        else
          result = getInstruction(AssignmentStoreTag())
      ) or
      (
        tag = AssignOperationConvertResultTag() and
        result = getInstruction(AssignmentStoreTag())
      ) or
      (
        tag = AssignmentStoreTag() and
        result = getParent().getChildSuccessor(this)
      )
    )
  }

  override Instruction getChildSuccessor(TranslatedElement child) {
    // Operands are evaluated right-to-left.
    (
      child = getRightOperand() and
      result = getLeftOperand().getFirstInstruction()
    ) or
    (
      child = getLeftOperand() and
      result = getInstruction(AssignOperationLoadTag())
    )
  }

  override Instruction getStoredValue() {
    if leftOperandNeedsConversion() then
      result = getInstruction(AssignOperationConvertResultTag())
    else
      result = getInstruction(AssignOperationOpTag())
  }

  private Type getConvertedLeftOperandType() {
    if(assignOp instanceof AssignLShiftExpr or
      assignOp instanceof AssignRShiftExpr or
      assignOp instanceof AssignPointerAddExpr or
      assignOp instanceof AssignPointerSubExpr) then (
      // No need to convert for a shift. Technically, the left side should
      // undergo integral promotion, and then the result would be converted back
      // to the destination type. There's not much point to this, though,
      // because the result will be the same for any well-defined program
      // anyway. If we really want to model this case perfectly, we'll need the
      // extractor to tell us what the promoted type of the left operand would
      // be.
      result = getLeftOperand().getResultType()
    ) else (
      // The right operand has already been converted to the type of the op.
      result = getRightOperand().getResultType()
    )
  }

  private predicate leftOperandNeedsConversion() {
    getConvertedLeftOperandType() != getLeftOperand().getResultType()
  }

  private Opcode getOpcode() {
    assignOp instanceof AssignAddExpr and result instanceof Opcode::Add or
    assignOp instanceof AssignSubExpr and result instanceof Opcode::Sub or
    assignOp instanceof AssignMulExpr and result instanceof Opcode::Mul or
    assignOp instanceof AssignDivExpr and result instanceof Opcode::Div or
    assignOp instanceof AssignRemExpr and result instanceof Opcode::Rem or
    assignOp instanceof AssignAndExpr and result instanceof Opcode::BitAnd or
    assignOp instanceof AssignOrExpr and result instanceof Opcode::BitOr or
    assignOp instanceof AssignXorExpr and result instanceof Opcode::BitXor or
    assignOp instanceof AssignLShiftExpr and result instanceof Opcode::ShiftLeft or
    assignOp instanceof AssignRShiftExpr and result instanceof Opcode::ShiftRight or
    assignOp instanceof AssignPointerAddExpr and result instanceof Opcode::PointerAdd or
    assignOp instanceof AssignPointerSubExpr and result instanceof Opcode::PointerSub
  }

  override predicate hasInstruction(Opcode opcode, InstructionTag tag,
    Type resultType, boolean isGLValue) {
    isGLValue = false and
    (
      (
        tag = AssignOperationLoadTag() and
        opcode instanceof Opcode::Load and
        resultType = getLeftOperand().getResultType()
      ) or
      (
        tag = AssignOperationOpTag() and
        opcode = getOpcode() and
        resultType = getConvertedLeftOperandType()
      ) or
      (
        tag = AssignmentStoreTag() and
        opcode instanceof Opcode::Store and
        resultType = getResultType()
      ) or
      (
        leftOperandNeedsConversion() and
        opcode instanceof Opcode::Convert and
        (
          (
            tag = AssignOperationConvertLeftTag() and
            resultType = getConvertedLeftOperandType()
          ) or
          (
            tag = AssignOperationConvertResultTag() and
            resultType = getLeftOperand().getResultType()
          )
        )
      )
    )
  }

  override int getInstructionElementSize(InstructionTag tag) {
    tag = AssignOperationOpTag() and
    exists(Opcode opcode |
      opcode = getOpcode() and
      (opcode instanceof Opcode::PointerAdd or opcode instanceof Opcode::PointerSub)
    ) and
    result = max(getResultType().(PointerType).getBaseType().getSize())
  }

  override Instruction getInstructionOperand(InstructionTag tag,
    OperandTag operandTag) {
    (
      tag = AssignOperationLoadTag() and
      (
        (
          operandTag instanceof LoadStoreAddressOperand and
          result = getLeftOperand().getResult()
        ) or
        (
          operandTag instanceof CopySourceOperand and
          result = getEnclosingFunction().getUnmodeledDefinitionInstruction()
        )
      )
    ) or
    (
      leftOperandNeedsConversion() and
      tag = AssignOperationConvertLeftTag() and
      operandTag instanceof UnaryOperand and
      result = getInstruction(AssignOperationLoadTag())
    ) or
    (
      tag = AssignOperationOpTag() and
      (
        (
          operandTag instanceof LeftOperand and
          if leftOperandNeedsConversion() then
            result = getInstruction(AssignOperationConvertLeftTag())
          else
            result = getInstruction(AssignOperationLoadTag())
        ) or
        (
          operandTag instanceof RightOperand and
          result = getRightOperand().getResult()
        )
      )
    ) or
    (
      leftOperandNeedsConversion() and
      tag = AssignOperationConvertResultTag() and
      operandTag instanceof UnaryOperand and
      result = getInstruction(AssignOperationOpTag())
    ) or
    (
      tag = AssignmentStoreTag() and
      (
        (
          operandTag instanceof LoadStoreAddressOperand and
          result = getLeftOperand().getResult()
        ) or
        (
          operandTag instanceof CopySourceOperand and
          result = getStoredValue()
        )
      )
    )
  }
}

/**
 * The IR translation of a call to a function. The call may be from an actual
 * call in the source code, or could be a call that is part of the translation
 * of a higher-level constructor (e.g. the allocator call in a `NewExpr`).
 */
abstract class TranslatedCall extends TranslatedExpr {
  override final TranslatedElement getChild(int id) {
    // We choose the child's id in the order of evaluation.
    // The qualifier is evaluated before the call target, because the value of
    // the call target may depend on the value of the qualifier for virtual
    // calls.
    id = -2 and result = getQualifier() or
    id = -1 and result = getCallTarget() or
    result = getArgument(id)
  }

  override final Instruction getFirstInstruction() {
    if exists(getQualifier()) then
      result = getQualifier().getFirstInstruction()
    else
      result = getFirstCallTargetInstruction()
  }

  override predicate hasInstruction(Opcode opcode, InstructionTag tag,
    Type resultType, boolean isGLValue) {
    tag = CallTag() and
    opcode instanceof Opcode::Invoke and
    resultType = getCallResultType() and
    isGLValue = false
  }
  
  override Instruction getChildSuccessor(TranslatedElement child) {
    (
      child = getQualifier() and
      result = getFirstCallTargetInstruction()
    ) or
    (
      child = getCallTarget() and
      result = getFirstArgumentOrCallInstruction()
    ) or
    exists(int argIndex |
      child = getArgument(argIndex) and
      if exists(getArgument(argIndex + 1)) then
        result = getArgument(argIndex + 1).getFirstInstruction()
      else
        result = getInstruction(CallTag())
    )
  }

  override Instruction getInstructionSuccessor(InstructionTag tag,
    EdgeKind kind) {
    kind instanceof GotoEdge and
    tag = CallTag() and
    result = getParent().getChildSuccessor(this)
  }

  override Instruction getInstructionOperand(InstructionTag tag,
    OperandTag operandTag) {
    tag = CallTag() and
    (
      (
        operandTag instanceof CallTargetOperand and
        result = getCallTargetResult()
      ) or
      (
        operandTag instanceof ThisArgumentOperand and
        result = getQualifierResult()
      ) or
      exists(PositionalArgumentOperand argTag |
        argTag = operandTag and
        result = getArgument(argTag.getArgIndex()).getResult()
      )
    )
  }

  override final Instruction getResult() {
    result = getInstruction(CallTag())
  }

  /**
   * Gets the result type of the call.
   */
  abstract Type getCallResultType();

  /**
   * Holds if the call has a `this` argument.
   */
  predicate hasQualifier() {
    exists(getQualifier())
  }

  /**
   * Gets the `TranslatedExpr` for the indirect target of the call, if any.
   */
  TranslatedExpr getCallTarget() {
    none()
  }

  /**
   * Gets the first instruction of the sequence to evaluate the call target.
   * By default, this is just the first instruction of `getCallTarget()`, but
   * it can be overridden by a subclass for cases where there is a call target
   * that is not computed from an expression (e.g. a direct call).
   */
  Instruction getFirstCallTargetInstruction() {
    result = getCallTarget().getFirstInstruction()
  }

  /**
   * Gets the instruction whose result value is the target of the call. By
   * default, this is just the result of `getCallTarget()`, but it can be
   * overridden by a subclass for cases where there is a call target that is not
   * computed from an expression (e.g. a direct call).
   */
  Instruction getCallTargetResult() {
    result = getCallTarget().getResult()
  }

  /**
   * Gets the `TranslatedExpr` for the qualifier of the call (i.e. the value
   * that is passed as the `this` argument.
   */
  abstract TranslatedExpr getQualifier();

  /**
   * Gets the instruction whose result value is the `this` argument of the call.
   * By default, this is just the result of `getQualifier()`, but it can be
   * overridden by a subclass for cases where there is a `this` argument that is
   * not computed from a child expression (e.g. a constructor call).
   */
  Instruction getQualifierResult() {
    result = getQualifier().getResult()
  }

  /**
   * Gets the argument with the specified `index`. Does not include the `this`
   * argument.
   */
  abstract TranslatedExpr getArgument(int index);

  /**
   * If there are any arguments, gets the first instruction of the first
   * argument. Otherwise, returns the call instruction.
   */
  final Instruction getFirstArgumentOrCallInstruction() {
    if hasArguments() then
      result = getArgument(0).getFirstInstruction()
    else
      result = getInstruction(CallTag())
  }

  /**
   * Holds if the call has any arguments, not counting the `this` argument.
   */
  abstract predicate hasArguments();
}

/**
 * The IR translation of the allocation size argument passed to `operator new`
 * in a `new` expression.
 *
 * We have to synthesize this because not all `NewExpr` nodes have an allocator
 * call, and even the ones that do pass an `ErrorExpr` as the argument.
 */
abstract class TranslatedAllocationSize extends TranslatedExpr,
    TTranslatedAllocationSize {
  NewOrNewArrayExpr newExpr;
  
  TranslatedAllocationSize() {
    this = TTranslatedAllocationSize(newExpr) and
    expr = newExpr
  }

  override final string toString() {
    result = "Allocation size for " + newExpr.toString()
  }

  override final predicate producesExprResult() {
    none()
  }

  override final Instruction getResult() {
    result = getInstruction(AllocationSizeTag())
  }
}

TranslatedAllocationSize getTranslatedAllocationSize(NewOrNewArrayExpr newExpr) {
  result.getAST() = newExpr
}

/**
 * The IR translation of a constant allocation size.
 *
 * The allocation size for a `new` expression is always a constant. The
 * allocation size for a `new[]` expression is a constant if the array extent
 * is a compile-time constant.
 */
class TranslatedConstantAllocationSize extends TranslatedAllocationSize {
  TranslatedConstantAllocationSize() {
    not exists(newExpr.(NewArrayExpr).getExtent())
  }

  override final Instruction getFirstInstruction() {
    result = getInstruction(AllocationSizeTag())
  }

  override final predicate hasInstruction(Opcode opcode, InstructionTag tag,
      Type resultType, boolean isGLValue) {
    tag = AllocationSizeTag() and
    opcode instanceof Opcode::Constant and
    resultType = newExpr.getAllocator().getParameter(0).getType().getUnspecifiedType() and
    isGLValue = false
  }

  override final Instruction getInstructionSuccessor(InstructionTag tag,
      EdgeKind kind) {
    tag = AllocationSizeTag() and
    kind instanceof GotoEdge and
    result = getParent().getChildSuccessor(this)
  }

  override final TranslatedElement getChild(int id) {
    none()
  }

  override final Instruction getChildSuccessor(TranslatedElement child) {
    none()
  }

  override final string getInstructionConstantValue(InstructionTag tag) {
    tag = AllocationSizeTag() and
    result = newExpr.getAllocatedType().getSize().toString()
  }
}

/**
 * The IR translation of a non-constant allocation size.
 *
 * This class is used for the allocation size of a `new[]` expression where the
 * array extent is not known at compile time. It performs the multiplication of
 * the extent by the element size.
 */
class TranslatedNonConstantAllocationSize extends TranslatedAllocationSize {
  NewArrayExpr newArrayExpr;

  TranslatedNonConstantAllocationSize() {
    newArrayExpr = newExpr and
    exists(newArrayExpr.getExtent())
  }

  override final Instruction getFirstInstruction() {
    result = getExtent().getFirstInstruction()
  }

  override final predicate hasInstruction(Opcode opcode, InstructionTag tag,
      Type resultType, boolean isGLValue) {
    isGLValue = false and
    resultType = newExpr.getAllocator().getParameter(0).getType().getUnspecifiedType() and
    (
      // Convert the extent to `size_t`, because the AST doesn't do this already.
      tag = AllocationExtentConvertTag() and opcode instanceof Opcode::Convert or
      tag = AllocationElementSizeTag() and opcode instanceof Opcode::Constant or
      tag = AllocationSizeTag() and opcode instanceof Opcode::Mul // REVIEW: Overflow?
    )
  }

  override final Instruction getInstructionSuccessor(InstructionTag tag,
      EdgeKind kind) {
    kind instanceof GotoEdge and
    (
      (
        tag = AllocationExtentConvertTag() and
        result = getInstruction(AllocationElementSizeTag())
      ) or
      (
        tag = AllocationElementSizeTag() and
        result = getInstruction(AllocationSizeTag())
      ) or
      (
        tag = AllocationSizeTag() and
        result = getParent().getChildSuccessor(this)
      )
    )
  }

  override final TranslatedElement getChild(int id) {
    id = 0 and result = getExtent()
  }

  override final Instruction getChildSuccessor(TranslatedElement child) {
    child = getExtent() and
    result = getInstruction(AllocationExtentConvertTag())
  }

  override final string getInstructionConstantValue(InstructionTag tag) {
    tag = AllocationElementSizeTag() and
    result = newArrayExpr.getAllocatedElementType().getSize().toString()
  }

  override final Instruction getInstructionOperand(InstructionTag tag,
      OperandTag operandTag) {
    (
      tag = AllocationSizeTag() and
      (
        operandTag instanceof LeftOperand and result = getInstruction(AllocationExtentConvertTag()) or
        operandTag instanceof RightOperand and result = getInstruction(AllocationElementSizeTag())
      )
    ) or
    (
      tag = AllocationExtentConvertTag() and
      operandTag instanceof UnaryOperand and
      result = getExtent().getResult()
    )
  }

  private TranslatedExpr getExtent() {
    result = getTranslatedExpr(newArrayExpr.getExtent().getFullyConverted())
  }
}

/**
 * IR translation of a direct call to a specific function. Used for both
 * explicit calls (`TranslatedFunctionCall`) and implicit calls
 * (`TranslatedAllocatorCall`).
 */
abstract class TranslatedDirectCall extends TranslatedCall {
  override final Instruction getFirstCallTargetInstruction() {
    result = getInstruction(CallTargetTag())
  }

  override final Instruction getCallTargetResult() {
    result = getInstruction(CallTargetTag())
  }

  override predicate hasInstruction(Opcode opcode, InstructionTag tag,
      Type resultType, boolean isGLValue) {
    TranslatedCall.super.hasInstruction(opcode, tag, resultType, isGLValue) or
    (
      tag = CallTargetTag() and
      opcode instanceof Opcode::FunctionAddress and
      // The database does not contain a `FunctionType` for a function unless
      // its address was taken, so we'll just use glval<Unknown> instead of
      // glval<FunctionType>.
      resultType instanceof UnknownType and
      isGLValue = true
    )
  }
  
  override Instruction getInstructionSuccessor(InstructionTag tag,
      EdgeKind kind) {
    result = TranslatedCall.super.getInstructionSuccessor(tag, kind) or
    (
      tag = CallTargetTag() and
      kind instanceof GotoEdge and
      result = getFirstArgumentOrCallInstruction()
    )
  }
}

/**
 * The IR translation of a call to `operator new` as part of a `new` or `new[]`
 * expression.
 */
class TranslatedAllocatorCall extends TTranslatedAllocatorCall,
    TranslatedDirectCall {
  NewOrNewArrayExpr newExpr;

  TranslatedAllocatorCall() {
    this = TTranslatedAllocatorCall(newExpr) and
    expr = newExpr
  }

  override final string toString() {
    result = "Allocator call for " + newExpr.toString()
  }

  override final predicate producesExprResult() {
    none()
  }

  override Function getInstructionFunction(InstructionTag tag) {
    tag = CallTargetTag() and result = newExpr.getAllocator()
  }

  override final Type getCallResultType() {
    result = newExpr.getAllocator().getType().getUnspecifiedType()
  }

  override final TranslatedExpr getQualifier() {
    none()
  }

  override final predicate hasArguments() {
    // All allocator calls have at least one argument.
    any()
  }

  override final TranslatedExpr getArgument(int index) {
    // If the allocator is the default operator new(void*), there will be no
    // allocator call in the AST. Otherwise, there will be an allocator call
    // that includes all arguments to the allocator, including the size,
    // alignment (if any), and placement args. However, the size argument is
    // an error node, so we need to provide the correct size argument in any
    // case.
    if index = 0 then
      result = getTranslatedAllocationSize(newExpr)
    else if(index = 1 and newExpr.hasAlignedAllocation()) then
      result = getTranslatedExpr(newExpr.getAlignmentArgument())
    else
      result = getTranslatedExpr(newExpr.getAllocatorCall().getArgument(index))
  }
}

TranslatedAllocatorCall getTranslatedAllocatorCall(NewOrNewArrayExpr newExpr) {
  result.getAST() = newExpr
}

/**
 * The IR translation of a call to a function.
 */
abstract class TranslatedCallExpr extends TranslatedNonConstantExpr,
    TranslatedCall {
  Call call;

  TranslatedCallExpr() {
    expr = call
  }

  override final Type getCallResultType() {
    result = getResultType()
  }

  override final predicate hasArguments() {
    exists(call.getArgument(0))
  }

  override final TranslatedExpr getQualifier() {
    result = getTranslatedExpr(call.getQualifier().getFullyConverted())
  }

  override final TranslatedExpr getArgument(int index) {
    result = getTranslatedExpr(call.getArgument(index).getFullyConverted())
  }
}

/**
 * Represents the IR translation of a call through a function pointer.
 */
class TranslatedExprCall extends TranslatedCallExpr {
  ExprCall exprCall;

  TranslatedExprCall() {
    expr = exprCall
  }

  override TranslatedExpr getCallTarget() {
    result = getTranslatedExpr(exprCall.getExpr().getFullyConverted())
  }
}

/**
 * Represents the IR translation of a direct function call.
 */
class TranslatedFunctionCall extends TranslatedCallExpr, TranslatedDirectCall {
  FunctionCall funcCall;

  TranslatedFunctionCall() {
    expr = funcCall
  }

  override Function getInstructionFunction(InstructionTag tag) {
    tag = CallTargetTag() and result = funcCall.getTarget()
  }
}

/**
 * Abstract class implemented by any `TranslatedElement` that has a child
 * expression that is a call to a constructor or destructor, in order to
 * provide a pointer to the object being constructed or destroyed.
 */
abstract class StructorCallContext extends TranslatedElement {
  /**
   * Gets the instruction whose result value is the address of the object to be
   * constructed or destroyed.
   */
  abstract Instruction getReceiver();
}

/**
 * Represents the IR translation of a call to a constructor.
 */
class TranslatedStructorCall extends TranslatedFunctionCall {
  TranslatedStructorCall() {
    funcCall instanceof ConstructorCall or
    funcCall instanceof DestructorCall
  }

  override Instruction getQualifierResult() {
    exists(StructorCallContext context |
      context = getParent() and
      result = context.getReceiver()
    )
  }

  override predicate hasQualifier() {
    any()
  }
}

/**
 * Represents the IR translation of the destruction of a field from within
 * the destructor of the field's declaring class.
 */
class TranslatedDestructorFieldDestruction extends TranslatedNonConstantExpr,
    StructorCallContext {
  DestructorFieldDestruction destruction;

  TranslatedDestructorFieldDestruction() {
    destruction = expr
  }

  override final TranslatedElement getChild(int id) {
    id = 0 and result = getDestructorCall()
  }

  override final predicate hasInstruction(Opcode opcode, InstructionTag tag,
    Type resultType, boolean isGLValue) {
    tag = OnlyInstructionTag() and
    opcode instanceof Opcode::FieldAddress and
    resultType = destruction.getTarget().getType().getUnspecifiedType() and
    isGLValue = true
  }

  override final Instruction getInstructionSuccessor(InstructionTag tag,
    EdgeKind kind) {
    tag = OnlyInstructionTag() and
    kind instanceof GotoEdge and
    result = getDestructorCall().getFirstInstruction()
  }

  override final Instruction getChildSuccessor(TranslatedElement child) {
    child = getDestructorCall() and
    result = getParent().getChildSuccessor(this)
  }

  override final Instruction getResult() {
    none()
  }

  override final Instruction getFirstInstruction() {
    result = getInstruction(OnlyInstructionTag())
  }

  override final Instruction getInstructionOperand(InstructionTag tag, OperandTag operandTag) {
    tag = OnlyInstructionTag() and
    operandTag instanceof UnaryOperand and
    result = getTranslatedFunction(destruction.getEnclosingFunction()).getInitializeThisInstruction()
  }

  override final Field getInstructionField(InstructionTag tag) {
    tag = OnlyInstructionTag() and
    result = destruction.getTarget()
  }

  override final Instruction getReceiver() {
    result = getInstruction(OnlyInstructionTag())
  }

  private TranslatedExpr getDestructorCall() {
    result = getTranslatedExpr(destruction.getExpr())
  }
}

class TranslatedConditionalExpr extends TranslatedNonConstantExpr,
  ConditionContext {
  ConditionalExpr condExpr;

  TranslatedConditionalExpr() {
    condExpr = expr
  }

  override final TranslatedElement getChild(int id) {
    id = 0 and result = getCondition() or
    id = 1 and result = getThen() or
    id = 2 and result = getElse()
  }

  override Instruction getFirstInstruction() {
    result = getCondition().getFirstInstruction()
  }

  override predicate hasInstruction(Opcode opcode, InstructionTag tag,
    Type resultType, boolean isGLValue) {
    not resultIsVoid() and
    (
      (
        (
          (not thenIsVoid() and (tag = ConditionValueTrueTempAddressTag())) or
          (not elseIsVoid() and (tag = ConditionValueFalseTempAddressTag())) or
          tag = ConditionValueResultTempAddressTag()
        ) and
        opcode instanceof Opcode::VariableAddress and
        resultType = getResultType() and
        isGLValue = true
      ) or
      (
        (
          (not thenIsVoid() and (tag = ConditionValueTrueStoreTag())) or
          (not elseIsVoid() and (tag = ConditionValueFalseStoreTag()))
        ) and
        opcode instanceof Opcode::Store and
        resultType = getResultType() and
        isGLValue = false
      ) or
      (
        tag = ConditionValueResultLoadTag() and
        opcode instanceof Opcode::Load and
        resultType = getResultType() and
        isGLValue = isResultGLValue()
      )
    )
  }

  override Instruction getInstructionSuccessor(InstructionTag tag,
    EdgeKind kind) {
    not resultIsVoid() and
    kind instanceof GotoEdge and
    (
      (
        not thenIsVoid() and
        (
          (
            tag = ConditionValueTrueTempAddressTag() and
            result = getInstruction(ConditionValueTrueStoreTag())
          ) or
          (
            tag = ConditionValueTrueStoreTag() and
            result = getInstruction(ConditionValueResultTempAddressTag())
          )
        )
      ) or
      (
        not elseIsVoid() and
        (
          (
            tag = ConditionValueFalseTempAddressTag() and
            result = getInstruction(ConditionValueFalseStoreTag())
          ) or
          (
            tag = ConditionValueFalseStoreTag() and
            result = getInstruction(ConditionValueResultTempAddressTag())
          )
        )
      ) or
      (
        tag = ConditionValueResultTempAddressTag() and
        result = getInstruction(ConditionValueResultLoadTag())
      ) or
      (
        tag = ConditionValueResultLoadTag() and
        result = getParent().getChildSuccessor(this)
      )
    )
  }

  override Instruction getInstructionOperand(InstructionTag tag,
    OperandTag operandTag) {
    not resultIsVoid() and
    (
      (
        not thenIsVoid() and
        tag = ConditionValueTrueStoreTag() and
        (
          (
            operandTag instanceof LoadStoreAddressOperand and
            result = getInstruction(ConditionValueTrueTempAddressTag())
          ) or
          (
            operandTag instanceof CopySourceOperand and
            result = getThen().getResult()
          )
        )
      ) or
      (
        not elseIsVoid() and
        tag = ConditionValueFalseStoreTag() and
        (
          (
            operandTag instanceof LoadStoreAddressOperand and
            result = getInstruction(ConditionValueFalseTempAddressTag())
          ) or
          (
            operandTag instanceof CopySourceOperand and
            result = getElse().getResult()
          )
        )
      ) or
      (
        tag = ConditionValueResultLoadTag() and
        (
          (
            operandTag instanceof LoadStoreAddressOperand and
            result = getInstruction(ConditionValueResultTempAddressTag())
          ) or
          (
            operandTag instanceof CopySourceOperand and
            result = getEnclosingFunction().getUnmodeledDefinitionInstruction()
          )
        )
      )
    )
  }

  override predicate hasTempVariable(TempVariableTag tag, Type type) {
    not resultIsVoid() and
    tag = ConditionValueTempVar() and
    type = getResultType()
  }

  override IRVariable getInstructionVariable(InstructionTag tag) {
    not resultIsVoid() and
    (
      tag = ConditionValueTrueTempAddressTag() or
      tag = ConditionValueFalseTempAddressTag() or
      tag = ConditionValueResultTempAddressTag()
    ) and
    result = getTempVariable(ConditionValueTempVar())
  }

  override Instruction getResult() {
    not resultIsVoid() and
    result = getInstruction(ConditionValueResultLoadTag())
  }

  override Instruction getChildSuccessor(TranslatedElement child) {
    (
      child = getThen() and
      if thenIsVoid() then
        result = getParent().getChildSuccessor(this)
      else
        result = getInstruction(ConditionValueTrueTempAddressTag())
    ) or
    (
      child = getElse() and
      if elseIsVoid() then
        result = getParent().getChildSuccessor(this)
      else
        result = getInstruction(ConditionValueFalseTempAddressTag())
    )
  }

  override Instruction getChildTrueSuccessor(TranslatedCondition child) {
    child = getCondition() and
    result = getThen().getFirstInstruction()
  }

  override Instruction getChildFalseSuccessor(TranslatedCondition child) {
    child = getCondition() and
    result = getElse().getFirstInstruction()
  }
  
  private TranslatedCondition getCondition() {
    result = getTranslatedCondition(condExpr.getCondition().getFullyConverted())
  }

  private TranslatedExpr getThen() {
    result = getTranslatedExpr(condExpr.getThen().getFullyConverted())
  }

  private TranslatedExpr getElse() {
    result = getTranslatedExpr(condExpr.getElse().getFullyConverted())
  }

  private predicate thenIsVoid() {
    getThen().getResultType() instanceof VoidType or
    // A `ThrowExpr.getType()` incorrectly returns the type of exception being
    // thrown, rather than `void`. Handle that case here.
    condExpr.getThen() instanceof ThrowExpr
  }

  private predicate elseIsVoid() {
    getElse().getResultType() instanceof VoidType or
    // A `ThrowExpr.getType()` incorrectly returns the type of exception being
    // thrown, rather than `void`. Handle that case here.
    condExpr.getElse() instanceof ThrowExpr
  }

  private predicate resultIsVoid() {
    getResultType() instanceof VoidType
  }
}

/**
 * IR translation of a `throw` expression.
 */
abstract class TranslatedThrowExpr extends TranslatedNonConstantExpr {
  ThrowExpr throw;

  TranslatedThrowExpr() {
    throw = expr
  }

  override predicate hasInstruction(Opcode opcode, InstructionTag tag,
      Type resultType, boolean isGLValue) {
    tag = ThrowTag() and
    opcode = getThrowOpcode() and
    resultType instanceof VoidType and
    isGLValue = false
  }

  override Instruction getInstructionSuccessor(InstructionTag tag,
      EdgeKind kind) {
    tag = ThrowTag() and
    kind instanceof ExceptionEdge and
    result = getParent().getExceptionSuccessorInstruction()
  }

  override Instruction getResult() {
    none()
  }

  abstract Opcode getThrowOpcode();
}

/**
 * IR translation of a `throw` expression with an argument
 * (e.g. `throw std::bad_alloc()`).
 */
class TranslatedThrowValueExpr extends TranslatedThrowExpr,
    InitializationContext {
  TranslatedThrowValueExpr() {
    not throw instanceof ReThrowExpr
  }

  override TranslatedElement getChild(int id) {
    id = 0 and result = getInitialization()
  }

  override Instruction getFirstInstruction() {
    result = getInstruction(InitializerVariableAddressTag())
  }

  override predicate hasInstruction(Opcode opcode, InstructionTag tag,
      Type resultType, boolean isGLValue) {
    TranslatedThrowExpr.super.hasInstruction(opcode, tag, resultType, isGLValue) or
    tag = InitializerVariableAddressTag() and
    opcode instanceof Opcode::VariableAddress and
    resultType = getExceptionType() and
    isGLValue = true
  }

  override Instruction getInstructionSuccessor(InstructionTag tag,
      EdgeKind kind) {
    result = TranslatedThrowExpr.super.getInstructionSuccessor(tag, kind) or
    (
      tag = InitializerVariableAddressTag() and
      result = getInitialization().getFirstInstruction() and
      kind instanceof GotoEdge
    )
  }

  override Instruction getChildSuccessor(TranslatedElement child) {
    child = getInitialization() and
    result = getInstruction(ThrowTag())
  }

  override IRVariable getInstructionVariable(InstructionTag tag) {
    tag = InitializerVariableAddressTag() and
    result = getIRTempVariable(throw, ThrowTempVar())
  }

  override final predicate hasTempVariable(TempVariableTag tag, Type type) {
    tag = ThrowTempVar() and
    type = getExceptionType()
  }

  override final Instruction getInstructionOperand(InstructionTag tag,
      OperandTag operandTag) {
    tag = ThrowTag() and
    (
      (
        operandTag instanceof LoadStoreAddressOperand and
        result = getInstruction(InitializerVariableAddressTag())
      ) or
      (
        operandTag instanceof ExceptionOperand and
        result = getEnclosingFunction().getUnmodeledDefinitionInstruction()
      )
    )
  }

  override Instruction getTargetAddress() {
    result = getInstruction(InitializerVariableAddressTag())
  }

  override Type getTargetType() {
    result = getExceptionType()
  }

  TranslatedInitialization getInitialization() {
    result = getTranslatedInitialization(
      throw.getExpr().getFullyConverted())
  }

  override final Opcode getThrowOpcode() {
    result instanceof Opcode::ThrowValue
  }

  private Type getExceptionType() {
    result = throw.getType().getUnspecifiedType()
  }
}

/**
 * IR translation of a `throw` expression with no argument (e.g. `throw;`).
 */
class TranslatedReThrowExpr extends TranslatedThrowExpr {
  TranslatedReThrowExpr() {
    throw instanceof ReThrowExpr
  }

  override TranslatedElement getChild(int id) {
    none()
  }

  override Instruction getFirstInstruction() {
    result = getInstruction(ThrowTag())
  }

  override Instruction getChildSuccessor(TranslatedElement child) {
    none()
  }

  override final Opcode getThrowOpcode() {
    result instanceof Opcode::ReThrow
  }
}

/**
 * The IR translation of a built-in operation (i.e. anything that extends
 * `BuiltInOperation`).
 */
abstract class TranslatedBuiltInOperation extends TranslatedNonConstantExpr {
  override final Instruction getResult() {
    result = getInstruction(OnlyInstructionTag())
  }

  override final Instruction getFirstInstruction() {
    if exists(getChild(0)) then 
      result = getChild(0).getFirstInstruction()
    else
      result = getInstruction(OnlyInstructionTag())
  }

  override final TranslatedElement getChild(int id) {
    result = getTranslatedExpr(expr.getChild(id).getFullyConverted())
  }

  override final Instruction getInstructionSuccessor(InstructionTag tag,
      EdgeKind kind) {
    tag = OnlyInstructionTag() and
    kind instanceof GotoEdge and
    result = getParent().getChildSuccessor(this)
  }

  override final Instruction getChildSuccessor(TranslatedElement child) {
    exists(int id |
      child = getChild(id) and
      (
        result = getChild(id + 1).getFirstInstruction() or
        not exists(getChild(id + 1)) and result = getInstruction(OnlyInstructionTag())
      )
    )
  }

  override final predicate hasInstruction(Opcode opcode, InstructionTag tag,
      Type resultType, boolean isGLValue) {
    tag = OnlyInstructionTag() and
    opcode = getOpcode() and
    resultType = getResultType() and
    isGLValue = isResultGLValue()
  }

  override final Instruction getInstructionOperand(InstructionTag tag,
      OperandTag operandTag) {
    tag = OnlyInstructionTag() and
    exists(int index |
      operandTag = positionalArgumentOperand(index) and
      result = getChild(index).(TranslatedExpr).getResult()
    )
  }

  abstract Opcode getOpcode();
}

/**
 * The IR translation of a `BuiltInVarArgsStart` expression.
 */
class TranslatedVarArgsStart extends TranslatedBuiltInOperation {
  TranslatedVarArgsStart() {
    expr instanceof BuiltInVarArgsStart
  }

  override final Opcode getOpcode() {
    result instanceof Opcode::VarArgsStart
  }
}

/**
 * The IR translation of a `BuiltInVarArgsEnd` expression.
 */
class TranslatedVarArgsEnd extends TranslatedBuiltInOperation {
  TranslatedVarArgsEnd() {
    expr instanceof BuiltInVarArgsEnd
  }

  override final Opcode getOpcode() {
    result instanceof Opcode::VarArgsEnd
  }
}

/**
 * The IR translation of a `BuiltInVarArg` expression.
 */
class TranslatedVarArg extends TranslatedBuiltInOperation {
  TranslatedVarArg() {
    expr instanceof BuiltInVarArg
  }

  override final Opcode getOpcode() {
    result instanceof Opcode::VarArg
  }
}

/**
 * The IR translation of a `BuiltInVarArgCopy` expression.
 */
class TranslatedVarArgCopy extends TranslatedBuiltInOperation {
  TranslatedVarArgCopy() {
    expr instanceof BuiltInVarArgCopy
  }

  override final Opcode getOpcode() {
    result instanceof Opcode::VarArgCopy
  }
}

/**
 * The IR translation of a `new` or `new[]` expression.
 */
abstract class TranslatedNewOrNewArrayExpr extends TranslatedNonConstantExpr,
    InitializationContext {
  NewOrNewArrayExpr newExpr;

  TranslatedNewOrNewArrayExpr() {
    expr = newExpr
  }

  override final TranslatedElement getChild(int id) {
    id = 0 and result = getAllocatorCall() or
    id = 1 and result = getInitialization()
  }

  override final predicate hasInstruction(Opcode opcode, InstructionTag tag,
      Type resultType, boolean isGLValue) {
    tag = OnlyInstructionTag() and
    opcode instanceof Opcode::Convert and
    resultType = getResultType() and
    isGLValue = false
  }

  override final Instruction getFirstInstruction() {
    result = getAllocatorCall().getFirstInstruction()
  }

  override final Instruction getResult() {
    result = getInstruction(OnlyInstructionTag())
  }

  override final Instruction getInstructionSuccessor(InstructionTag tag,
      EdgeKind kind) {
    kind instanceof GotoEdge and
    tag = OnlyInstructionTag() and
    if exists(getInitialization()) then
      result = getInitialization().getFirstInstruction()
    else
      result = getParent().getChildSuccessor(this)
  }

  override final Instruction getChildSuccessor(TranslatedElement child) {
    child = getAllocatorCall() and result = getInstruction(OnlyInstructionTag()) or
    child = getInitialization() and result = getParent().getChildSuccessor(this)
  }

  override final Instruction getInstructionOperand(InstructionTag tag,
      OperandTag operandTag) {
    tag = OnlyInstructionTag() and
    operandTag instanceof UnaryOperand and
    result = getAllocatorCall().getResult()
  }
  
  override final Instruction getTargetAddress() {
    result = getInstruction(OnlyInstructionTag())
  }

  private TranslatedAllocatorCall getAllocatorCall() {
    result = getTranslatedAllocatorCall(newExpr)
  }

  abstract TranslatedInitialization getInitialization();
}

/**
 * The IR translation of a `new` expression.
 */
class TranslatedNewExpr extends TranslatedNewOrNewArrayExpr {
  TranslatedNewExpr() {
    newExpr instanceof NewExpr
  }

  override final Type getTargetType() {
    result = newExpr.getAllocatedType().getUnspecifiedType()
  }

  override final TranslatedInitialization getInitialization() {
    result = getTranslatedInitialization(newExpr.(NewExpr).getInitializer())
  }
}

/**
 * The IR translation of a `new[]` expression.
 */
class TranslatedNewArrayExpr extends TranslatedNewOrNewArrayExpr {
  TranslatedNewArrayExpr() {
    newExpr instanceof NewArrayExpr
  }

  override final Type getTargetType() {
    result = newExpr.getAllocatedType().getUnspecifiedType()
  }

  override final TranslatedInitialization getInitialization() {
    // REVIEW: Figure out how we want to model array initialization in the IR.
    none()
  }
}
