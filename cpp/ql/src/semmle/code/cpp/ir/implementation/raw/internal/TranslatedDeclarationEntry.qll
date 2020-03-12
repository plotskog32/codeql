private import cpp
private import semmle.code.cpp.ir.implementation.Opcode
private import semmle.code.cpp.ir.implementation.internal.OperandTag
private import semmle.code.cpp.ir.internal.CppType
private import semmle.code.cpp.ir.internal.IRUtilities
private import InstructionTag
private import TranslatedElement
private import TranslatedExpr
private import TranslatedFunction
private import TranslatedInitialization

/**
 * Gets the `TranslatedDeclarationEntry` that represents the declaration
 * `entry`.
 */
TranslatedDeclarationEntry getTranslatedDeclarationEntry(DeclarationEntry entry) {
  result.getAST() = entry
}

/**
 * Represents the IR translation of a declaration within the body of a function.
 * Most often, this is the declaration of an automatic local variable, although
 * it can also be the declaration of a static local variable. Declarations of extern variables and
 * functions do not have a `TranslatedDeclarationEntry`.
 */
abstract class TranslatedDeclarationEntry extends TranslatedElement, TTranslatedDeclarationEntry {
  DeclarationEntry entry;

  TranslatedDeclarationEntry() { this = TTranslatedDeclarationEntry(entry) }

  final override Function getFunction() {
    exists(DeclStmt stmt |
      stmt.getADeclarationEntry() = entry and
      result = stmt.getEnclosingFunction()
    )
  }

  final override string toString() { result = entry.toString() }

  final override Locatable getAST() { result = entry }
}

/**
 * Represents the IR translation of the declaration of a local variable,
 * including its initialization, if any.
 */
abstract class TranslatedLocalVariableDeclaration extends TranslatedVariableInitialization {
  /**
   * Gets the local variable being declared.
   */
  abstract LocalVariable getVariable();

  final override Type getTargetType() { result = getVariableType(getVariable()) }

  final override TranslatedInitialization getInitialization() {
    result =
      getTranslatedInitialization(getVariable().getInitializer().getExpr().getFullyConverted())
  }

  final override Instruction getInitializationSuccessor() {
    result = getParent().getChildSuccessor(this)
  }

  final override IRVariable getIRVariable() {
    result = getIRUserVariable(getFunction(), getVariable())
  }
}

/**
 * The IR translation of a local variable declaration within a declaration statement.
 */
class TranslatedAutoVariableDeclarationEntry extends TranslatedLocalVariableDeclaration,
  TranslatedDeclarationEntry {
  LocalVariable var;

  TranslatedAutoVariableDeclarationEntry() { var = entry.getDeclaration() and not var.isStatic() }

  override LocalVariable getVariable() { result = var }
}

/**
 * The IR translation of the declaration of a static local variable.
 * This element generates the logic that determines whether or not the variable has already been
 * initialized, and if not, invokes the initializer and sets the dynamic initialization flag for the
 * variable. The actual initialization code is handled in
 * `TranslatedStaticLocalVariableInitialization`, which is a child of this element.
 */
class TranslatedStaticLocalVariableDeclarationEntry extends TranslatedDeclarationEntry {
  LocalVariable var;

  TranslatedStaticLocalVariableDeclarationEntry() {
    var = entry.getDeclaration() and var.isStatic()
  }

  final override TranslatedElement getChild(int id) { id = 0 and result = getInitialization() }

  final override predicate hasInstruction(Opcode opcode, InstructionTag tag, CppType type) {
    tag = DynamicInitializationFlagAddressTag() and
    opcode instanceof Opcode::VariableAddress and
    type = getBoolGLValueType()
    or
    tag = DynamicInitializationFlagLoadTag() and
    opcode instanceof Opcode::Load and
    type = getBoolType()
    or
    tag = DynamicInitializationConditionalBranchTag() and
    opcode instanceof Opcode::ConditionalBranch and
    type = getVoidType()
    or
    tag = DynamicInitializationFlagConstantTag() and
    opcode instanceof Opcode::Constant and
    type = getBoolType()
    or
    tag = DynamicInitializationFlagStoreTag() and
    opcode instanceof Opcode::Store and
    type = getBoolType()
  }

  final override Instruction getFirstInstruction() {
    result = getInstruction(DynamicInitializationFlagAddressTag())
  }

  final override Instruction getInstructionSuccessor(InstructionTag tag, EdgeKind kind) {
    tag = DynamicInitializationFlagAddressTag() and
    kind instanceof GotoEdge and
    result = getInstruction(DynamicInitializationFlagLoadTag())
    or
    tag = DynamicInitializationFlagLoadTag() and
    kind instanceof GotoEdge and
    result = getInstruction(DynamicInitializationConditionalBranchTag())
    or
    tag = DynamicInitializationConditionalBranchTag() and
    (
      kind instanceof TrueEdge and
      result = getParent().getChildSuccessor(this)
      or
      kind instanceof FalseEdge and
      result = getInitialization().getFirstInstruction()
    )
    or
    tag = DynamicInitializationFlagConstantTag() and
    kind instanceof GotoEdge and
    result = getInstruction(DynamicInitializationFlagStoreTag())
    or
    tag = DynamicInitializationFlagStoreTag() and
    kind instanceof GotoEdge and
    result = getParent().getChildSuccessor(this)
  }

  final override Instruction getChildSuccessor(TranslatedElement child) {
    child = getInitialization() and
    result = getInstruction(DynamicInitializationFlagConstantTag())
  }

  final override IRDynamicInitializationFlag getInstructionVariable(InstructionTag tag) {
    tag = DynamicInitializationFlagAddressTag() and
    result.getVariable() = var
  }

  final override string getInstructionConstantValue(InstructionTag tag) {
    tag = DynamicInitializationFlagConstantTag() and result = "1"
  }

  final override Instruction getInstructionOperand(InstructionTag tag, OperandTag operandTag) {
    tag = DynamicInitializationFlagLoadTag() and
    (
      operandTag instanceof AddressOperandTag and
      result = getInstruction(DynamicInitializationFlagAddressTag())
      or
      operandTag instanceof LoadOperandTag and
      result = getTranslatedFunction(var.getFunction()).getUnmodeledDefinitionInstruction()
    )
    or
    tag = DynamicInitializationConditionalBranchTag() and
    operandTag instanceof ConditionOperandTag and
    result = getInstruction(DynamicInitializationFlagLoadTag())
    or
    tag = DynamicInitializationFlagStoreTag() and
    (
      operandTag instanceof AddressOperandTag and
      result = getInstruction(DynamicInitializationFlagAddressTag())
      or
      operandTag instanceof StoreValueOperandTag and
      result = getInstruction(DynamicInitializationFlagConstantTag())
    )
  }

  private TranslatedStaticLocalVariableInitialization getInitialization() {
    result.getVariable() = var
  }
}

/**
 * The initialization of a static local variable. This element will only exist for a static variable
 * with a dynamic initializer.
 */
class TranslatedStaticLocalVariableInitialization extends TranslatedElement,
  TranslatedLocalVariableDeclaration, TTranslatedStaticLocalVariableInitialization {
  VariableDeclarationEntry entry;
  LocalVariable var;

  TranslatedStaticLocalVariableInitialization() {
    this = TTranslatedStaticLocalVariableInitialization(entry) and
    var = entry.getDeclaration()
  }

  final override string toString() { result = "init: " + entry.toString() }

  final override Locatable getAST() { result = entry }

  final override LocalVariable getVariable() { result = var }

  final override Function getFunction() { result = var.getFunction() }
}

/**
 * Gets the `TranslatedRangeBasedForVariableDeclaration` that represents the declaration of
 * `var`.
 */
TranslatedRangeBasedForVariableDeclaration getTranslatedRangeBasedForVariableDeclaration(
  LocalVariable var
) {
  result.getVariable() = var
}

/**
 * Represents the IR translation of a compiler-generated variable in a range-based `for` loop.
 */
class TranslatedRangeBasedForVariableDeclaration extends TranslatedLocalVariableDeclaration,
  TTranslatedRangeBasedForVariableDeclaration {
  RangeBasedForStmt forStmt;
  LocalVariable var;

  TranslatedRangeBasedForVariableDeclaration() {
    this = TTranslatedRangeBasedForVariableDeclaration(forStmt, var)
  }

  override string toString() { result = var.toString() }

  override Locatable getAST() { result = var }

  override Function getFunction() { result = forStmt.getEnclosingFunction() }

  override LocalVariable getVariable() { result = var }
}

TranslatedConditionDecl getTranslatedConditionDecl(ConditionDeclExpr expr) {
  result.getAST() = expr
}

/**
 * Represents the IR translation of the declaration portion of a `ConditionDeclExpr`, which
 * represents the variable declared in code such as:
 * ```
 * if (int* p = &x) {
 * }
 * ```
 */
class TranslatedConditionDecl extends TranslatedLocalVariableDeclaration, TTranslatedConditionDecl {
  ConditionDeclExpr conditionDeclExpr;

  TranslatedConditionDecl() { this = TTranslatedConditionDecl(conditionDeclExpr) }

  override string toString() { result = "decl: " + conditionDeclExpr.toString() }

  override Locatable getAST() { result = conditionDeclExpr }

  override Function getFunction() { result = conditionDeclExpr.getEnclosingFunction() }

  override LocalVariable getVariable() { result = conditionDeclExpr.getVariable() }
}
