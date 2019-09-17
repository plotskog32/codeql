/**
 * Contains an abstract class that serves as a Base for the classes that deal with both the AST
 * generated declarations and the compiler generated ones (captures the common patterns).
 */

import csharp
private import semmle.code.csharp.ir.implementation.Opcode
private import semmle.code.csharp.ir.internal.IRUtilities
private import semmle.code.csharp.ir.implementation.internal.OperandTag
private import semmle.code.csharp.ir.implementation.raw.internal.InstructionTag
private import semmle.code.csharp.ir.implementation.raw.internal.TranslatedElement
private import semmle.code.csharp.ir.implementation.raw.internal.TranslatedExpr
private import semmle.code.csharp.ir.implementation.raw.internal.TranslatedInitialization
private import semmle.code.csharp.ir.internal.IRCSharpLanguage as Language

abstract class LocalVariableDeclarationBase extends TranslatedElement {
  override TranslatedElement getChild(int id) { id = 0 and result = getInitialization() }

  override Instruction getFirstInstruction() { result = getVarAddress() }

  override predicate hasInstruction(
    Opcode opcode, InstructionTag tag, Type resultType, boolean isLValue
  ) {
    tag = InitializerVariableAddressTag() and
    opcode instanceof Opcode::VariableAddress and
    resultType = getVarType() and
    isLValue = true
    or
    hasUninitializedInstruction() and
    tag = InitializerStoreTag() and
    opcode instanceof Opcode::Uninitialized and
    resultType = getVarType() and
    isLValue = false
  }

  override Instruction getInstructionSuccessor(InstructionTag tag, EdgeKind kind) {
    (
      tag = InitializerVariableAddressTag() and
      kind instanceof GotoEdge and
      if hasUninitializedInstruction()
      then result = getInstruction(InitializerStoreTag())
      else
        if isInitializedByElement()
        then
          // initialization is done by an element
          result = getParent().getChildSuccessor(this)
        else result = getInitialization().getFirstInstruction()
    )
    or
    hasUninitializedInstruction() and
    kind instanceof GotoEdge and
    tag = InitializerStoreTag() and
    (
      result = getInitialization().getFirstInstruction()
      or
      not exists(getInitialization()) and result = getParent().getChildSuccessor(this)
    )
  }

  override Instruction getChildSuccessor(TranslatedElement child) {
    child = getInitialization() and result = getParent().getChildSuccessor(this)
  }

  override Instruction getInstructionOperand(InstructionTag tag, OperandTag operandTag) {
    hasUninitializedInstruction() and
    tag = InitializerStoreTag() and
    operandTag instanceof AddressOperandTag and
    result = getVarAddress()
  }

  /**
   * Holds if the declaration should have an `Uninitialized` instruction.
   * Compiler generated elements should override this predicate and
   * make it empty, since we always initialize the vars declared during the
   * desugaring process.
   */
  predicate hasUninitializedInstruction() {
    (
      not exists(getInitialization()) or
      getInitialization() instanceof TranslatedListInitialization
    ) and
    not isInitializedByElement()
  }

  Instruction getVarAddress() { result = getInstruction(InitializerVariableAddressTag()) }

  /**
   * Gets the declared variable. For compiler generated elements, this
   * should be empty (since we treat temp vars differently).
   */
  abstract LocalVariable getDeclVar();

  /**
   * Gets the type of the declared variable.
   */
  abstract Type getVarType();

  /**
   * Gets the initialization, if there is one.
   * For compiler generated elements we don't treat the initialization
   * as a different step, but do it during the declaration.
   */
  abstract TranslatedElement getInitialization();

  /**
   * Holds if a declaration is not explicitly initialized,
   * but will be implicitly initialized by an element.
   */
  abstract predicate isInitializedByElement();
}
