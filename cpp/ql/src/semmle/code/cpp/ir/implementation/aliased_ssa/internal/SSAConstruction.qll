import SSAConstructionInternal
import cpp
private import semmle.code.cpp.ir.implementation.Opcode
private import semmle.code.cpp.ir.internal.OperandTag
private import NewIR

import Cached
cached private module Cached {

  private IRBlock getNewBlock(OldIR::IRBlock oldBlock) {
    result.getFirstInstruction() = getNewInstruction(oldBlock.getFirstInstruction())
  }

  cached newtype TInstructionTag =
    WrappedInstructionTag(OldIR::Instruction oldInstruction) {
      not oldInstruction instanceof OldIR::PhiInstruction
    } or
    PhiTag(Alias::VirtualVariable vvar, OldIR::IRBlock block) {
      hasPhiNode(vvar, block)
    } or
    ChiTag(OldIR::Instruction oldInstruction) {
      not oldInstruction instanceof OldIR::PhiInstruction and
      hasChiNode(_, oldInstruction)
    }

  cached class InstructionTagType extends TInstructionTag {
    cached final string toString() {
      result = "Tag"
    }
  }

  cached predicate functionHasIR(Function func) {
    exists(OldIR::FunctionIR funcIR |
      funcIR.getFunction() = func
    )
  }

  cached OldIR::Instruction getOldInstruction(Instruction instr) {
    instr.getTag() = WrappedInstructionTag(result)
  }

  private Instruction getNewInstruction(OldIR::Instruction instr) {
    getOldInstruction(result) = instr
  }

  private Instruction getNewFinalInstruction(OldIR::Instruction instr) {
    result = getChiInstruction(instr)
    or
    not exists(getChiInstruction(instr)) and
    result = getNewInstruction(instr)
  }

  private PhiInstruction getPhiInstruction(Function func, OldIR::IRBlock oldBlock,
    Alias::VirtualVariable vvar) {
    result.getFunction() = func and
    result.getAST() = oldBlock.getFirstInstruction().getAST() and
    result.getTag() = PhiTag(vvar, oldBlock)
  }
  
  private ChiInstruction getChiInstruction (OldIR::Instruction instr) {
    hasChiNode(_, instr) and
    result.getTag() = ChiTag(instr)
  }

  private IRVariable getNewIRVariable(OldIR::IRVariable var) {
    result.getFunction() = var.getFunction() and
    (
      exists(OldIR::IRUserVariable userVar, IRUserVariable newUserVar |
        userVar = var and
        newUserVar.getVariable() = userVar.getVariable() and
        result = newUserVar
      ) or
      exists(OldIR::IRTempVariable tempVar, IRTempVariable newTempVar |
        tempVar = var and
        newTempVar.getAST() = tempVar.getAST() and
        newTempVar.getTag() = tempVar.getTag() and
        result = newTempVar
      )
    )
  }

  cached newtype TInstruction =
    MkInstruction(FunctionIR funcIR, Opcode opcode, Locatable ast,
        InstructionTag tag, Type resultType, boolean isGLValue) {
      hasInstruction(funcIR.getFunction(), opcode, ast, tag,
        resultType, isGLValue)
    }

  private predicate hasInstruction(Function func, Opcode opcode, Locatable ast,
    InstructionTag tag, Type resultType, boolean isGLValue) {
    exists(OldIR::Instruction instr |
      instr.getFunction() = func and
      instr.getOpcode() = opcode and
      instr.getAST() = ast and
      WrappedInstructionTag(instr) = tag and
      instr.getResultType() = resultType and
      if instr.isGLValue() then
        isGLValue = true
      else
        isGLValue = false
    ) or
    exists(OldIR::IRBlock block, Alias::VirtualVariable vvar |
      hasPhiNode(vvar, block) and
      block.getFunction() = func and
      opcode instanceof Opcode::Phi and
      ast = block.getFirstInstruction().getAST() and
      tag = PhiTag(vvar, block) and
      resultType = vvar.getType() and
      isGLValue = false
    ) or
    exists(OldIR::Instruction instr, Alias::VirtualVariable vvar |
      hasChiNode(vvar, instr) and
      instr.getFunction() = func and
      opcode instanceof Opcode::Chi and
      ast = instr.getAST() and
      tag = ChiTag(instr) and
      resultType = vvar.getType() and
      isGLValue = false
    )
  }

  cached predicate hasTempVariable(Function func, Locatable ast, TempVariableTag tag,
    Type type) {
    exists(OldIR::IRTempVariable var |
      var.getFunction() = func and
      var.getAST() = ast and
      var.getTag() = tag and
      var.getType() = type
    )
  }

  cached predicate hasModeledMemoryResult(Instruction instruction) {
    exists(Alias::getResultMemoryAccess(getOldInstruction(instruction))) or
    instruction instanceof PhiInstruction  // Phis always have modeled results
  }

  cached Instruction getInstructionOperandDefinition(Instruction instruction, OperandTag tag) {
    exists(OldIR::Instruction oldInstruction, OldIR::NonPhiOperand oldOperand |
      oldInstruction = getOldInstruction(instruction) and
      oldOperand = oldInstruction.getAnOperand() and
      tag = oldOperand.getOperandTag() and
      if oldOperand instanceof OldIR::MemoryOperand then (
        (
          if exists(Alias::getOperandMemoryAccess(oldOperand)) then (
            exists(OldIR::IRBlock useBlock, int useRank, Alias::VirtualVariable vvar,
              OldIR::IRBlock defBlock, int defRank, int defIndex |
              vvar = Alias::getOperandMemoryAccess(oldOperand).getVirtualVariable() and
              hasDefinitionAtRank(vvar, defBlock, defRank, defIndex) and
              hasUseAtRank(vvar, useBlock, useRank, oldInstruction) and
              definitionReachesUse(vvar, defBlock, defRank, useBlock, useRank) and
              if defIndex >= 0 then
                result = getNewFinalInstruction(defBlock.getInstruction(defIndex))
              else
                result = getPhiInstruction(instruction.getFunction(), defBlock, vvar)
            )
          )
          else (
            result = instruction.getFunctionIR().getUnmodeledDefinitionInstruction()
          )
        ) or
        // Connect any definitions that are not being modeled in SSA to the
        // `UnmodeledUse` instruction.
        exists(OldIR::Instruction oldDefinition |
          instruction instanceof UnmodeledUseInstruction and
          tag instanceof UnmodeledUseOperandTag and
          oldDefinition = oldOperand.getDefinitionInstruction() and
          not exists(Alias::getResultMemoryAccess(oldDefinition)) and
          result = getNewInstruction(oldDefinition)
        )
      )
      else
        result = getNewInstruction(oldOperand.getDefinitionInstruction())
    ) or
    instruction.getTag() = ChiTag(getOldInstruction(result)) and
    tag instanceof ChiPartialOperandTag
    or
    result = getChiInstructionTotalOperand(instruction.(ChiInstruction), tag.(ChiTotalOperandTag))
  }

  cached Instruction getPhiInstructionOperandDefinition(PhiInstruction instr,
      IRBlock newPredecessorBlock) {
    exists(Alias::VirtualVariable vvar, OldIR::IRBlock phiBlock,
      OldIR::IRBlock defBlock, int defRank, int defIndex, OldIR::IRBlock predBlock |
      hasPhiNode(vvar, phiBlock) and
      predBlock = phiBlock.getAPredecessor() and
      instr.getTag() = PhiTag(vvar, phiBlock) and
      newPredecessorBlock = getNewBlock(predBlock) and
      hasDefinitionAtRank(vvar, defBlock, defRank, defIndex) and
      definitionReachesEndOfBlock(vvar, defBlock, defRank, predBlock) and
      if defIndex >= 0 then
        result = getNewFinalInstruction(defBlock.getInstruction(defIndex))
      else
        result = getPhiInstruction(instr.getFunction(), defBlock, vvar)
    )
  }

  cached Instruction getChiInstructionTotalOperand(ChiInstruction chiInstr, ChiTotalOperandTag tag) {
    exists(Alias::VirtualVariable vvar, OldIR::Instruction oldInstr, OldIR::IRBlock defBlock,
      int defRank, int defIndex, OldIR::IRBlock useBlock, int useRank |
       ChiTag(oldInstr) = chiInstr.getTag() and
       vvar = Alias::getResultMemoryAccess(oldInstr).getVirtualVariable() and
       hasDefinitionAtRank(vvar, defBlock, defRank, defIndex) and
       hasUseAtRank(vvar, useBlock, useRank, oldInstr) and
       definitionReachesUse(vvar, defBlock, defRank, useBlock, useRank) and
       result = getNewFinalInstruction(defBlock.getInstruction(defIndex))
    )
  }

  cached Instruction getPhiInstructionBlockStart(PhiInstruction instr) {
    exists(OldIR::IRBlock oldBlock |
      instr.getTag() = PhiTag(_, oldBlock) and
      result = getNewInstruction(oldBlock.getFirstInstruction())
    )
  }

  cached Expr getInstructionConvertedResultExpression(Instruction instruction) {
    result = getOldInstruction(instruction).getConvertedResultExpression()
  }

  cached Expr getInstructionUnconvertedResultExpression(Instruction instruction) {
    result = getOldInstruction(instruction).getUnconvertedResultExpression()
  }

  cached Instruction getInstructionSuccessor(Instruction instruction, EdgeKind kind) {
    if(hasChiNode(_, getOldInstruction(instruction)))
    then
      result = getChiInstruction(getOldInstruction(instruction)) and
      kind instanceof GotoEdge
    else (
      result = getNewInstruction(getOldInstruction(instruction).getSuccessor(kind))
      or
      exists(OldIR::Instruction oldInstruction |
        instruction = getChiInstruction(oldInstruction) and
        result = getNewInstruction(oldInstruction.getSuccessor(kind))
      )
    )
  }

  cached IRVariable getInstructionVariable(Instruction instruction) {
    result = getNewIRVariable(getOldInstruction(instruction).(OldIR::VariableInstruction).getVariable())
  }

  cached Field getInstructionField(Instruction instruction) {
    result = getOldInstruction(instruction).(OldIR::FieldInstruction).getField()
  }

  cached Function getInstructionFunction(Instruction instruction) {
    result = getOldInstruction(instruction).(OldIR::FunctionInstruction).getFunctionSymbol()
  }

  cached string getInstructionConstantValue(Instruction instruction) {
    result = getOldInstruction(instruction).(OldIR::ConstantValueInstruction).getValue()
  }

  cached StringLiteral getInstructionStringLiteral(Instruction instruction) {
    result = getOldInstruction(instruction).(OldIR::StringConstantInstruction).getValue()
  }

  cached Type getInstructionExceptionType(Instruction instruction) {
    result = getOldInstruction(instruction).(OldIR::CatchByTypeInstruction).getExceptionType()
  }

  cached int getInstructionElementSize(Instruction instruction) {
    result = getOldInstruction(instruction).(OldIR::PointerArithmeticInstruction).getElementSize()
  }

  cached int getInstructionResultSize(Instruction instruction) {
    // Only return a result for instructions that needed an explicit result size.
    instruction.getResultType() instanceof UnknownType and
    result = getOldInstruction(instruction).getResultSize()
  }

  cached predicate getInstructionInheritance(Instruction instruction, Class baseClass,
      Class derivedClass) {
    exists(OldIR::InheritanceConversionInstruction oldInstr |
      oldInstr = getOldInstruction(instruction) and
      baseClass = oldInstr.getBaseClass() and
      derivedClass = oldInstr.getDerivedClass()
    )
  }

  cached Instruction getPrimaryInstructionForSideEffect(Instruction instruction) {
    exists(OldIR::SideEffectInstruction oldInstruction |
      oldInstruction = getOldInstruction(instruction) and
      result = getNewInstruction(oldInstruction.getPrimaryInstruction())
    )
    or
    exists(OldIR::Instruction oldInstruction |
      instruction.getTag() = ChiTag(oldInstruction) and
      result = getNewInstruction(oldInstruction)
    )
  }

  private predicate ssa_variableUpdate(Alias::VirtualVariable vvar,
    OldIR::Instruction instr, OldIR::IRBlock block, int index) {
    block.getInstruction(index) = instr and
    Alias::getResultMemoryAccess(instr).getVirtualVariable() = vvar
  }

  private predicate hasDefinition(Alias::VirtualVariable vvar, OldIR::IRBlock block, int index) {
    (
      hasPhiNode(vvar, block) and
      index = -1
    ) or
    exists(Alias::MemoryAccess access, OldIR::Instruction def |
      access = Alias::getResultMemoryAccess(def) and
      block.getInstruction(index) = def and
      vvar = access.getVirtualVariable()
    )
  }

  private predicate defUseRank(Alias::VirtualVariable vvar, OldIR::IRBlock block, int rankIndex, int index) {
    index = rank[rankIndex](int j | hasDefinition(vvar, block, j) or hasUse(vvar, _, block, j))
  }

  private predicate hasUse(Alias::VirtualVariable vvar, 
    OldIR::Instruction use, OldIR::IRBlock block, int index) {
    exists(Alias::MemoryAccess access |
      (
        access = Alias::getOperandMemoryAccess(use.getAnOperand())
        or
        access = Alias::getResultMemoryAccess(use) and
        access.isPartialMemoryAccess()
      ) and
      block.getInstruction(index) = use and
      vvar = access.getVirtualVariable()
    )
  }

  private predicate variableLiveOnEntryToBlock(Alias::VirtualVariable vvar, OldIR::IRBlock block) {
    exists (int index | hasUse(vvar, _, block, index) |
      not exists (int j | ssa_variableUpdate(vvar, _, block, j) | j < index)
    ) or
    (variableLiveOnExitFromBlock(vvar, block) and not ssa_variableUpdate(vvar, _, block, _))
  }

  pragma[noinline]
  private predicate variableLiveOnExitFromBlock(Alias::VirtualVariable vvar, OldIR::IRBlock block) {
    variableLiveOnEntryToBlock(vvar, block.getASuccessor())
  }

  /**
   * Gets the rank index of a hyphothetical use one instruction past the end of
   * the block. This index can be used to determine if a definition reaches the
   * end of the block, even if the definition is the last instruction in the
   * block.
   */
  private int exitRank(Alias::VirtualVariable vvar, OldIR::IRBlock block) {
    result = max(int rankIndex | defUseRank(vvar, block, rankIndex, _)) + 1
  }

  private predicate hasDefinitionAtRank(Alias::VirtualVariable vvar,
    OldIR::IRBlock block, int rankIndex, int instructionIndex) {
    hasDefinition(vvar, block, instructionIndex) and
    defUseRank(vvar, block, rankIndex, instructionIndex)
  }

  private predicate hasUseAtRank(Alias::VirtualVariable vvar, OldIR::IRBlock block,
    int rankIndex, OldIR::Instruction use) {
    exists(int index |
      hasUse(vvar, use, block, index) and
      defUseRank(vvar, block, rankIndex, index)
    )
  }

  /**
    * Holds if the definition of `vvar` at `(block, defRank)` reaches the rank
    * index `reachesRank` in block `block`.
    */
  private predicate definitionReachesRank(Alias::VirtualVariable vvar,
    OldIR::IRBlock block, int defRank, int reachesRank) {
    hasDefinitionAtRank(vvar, block, defRank, _) and
    reachesRank <= exitRank(vvar, block) and  // Without this, the predicate would be infinite.
    (
      // The def always reaches the next use, even if there is also a def on the
      // use instruction.
      reachesRank = defRank + 1 or
      (
        // If the def reached the previous rank, it also reaches the current rank,
        // unless there was another def at the previous rank.
        definitionReachesRank(vvar, block, defRank, reachesRank - 1) and
        not hasDefinitionAtRank(vvar, block, reachesRank - 1, _)
      )
    )
  }

  /**
   * Holds if the definition of `vvar` at `(defBlock, defRank)` reaches the end of
   * block `block`.
   */
  private predicate definitionReachesEndOfBlock(Alias::VirtualVariable vvar,
    OldIR::IRBlock defBlock, int defRank, OldIR::IRBlock block) {
    hasDefinitionAtRank(vvar, defBlock, defRank, _) and
    (
      (
        // If we're looking at the def's own block, just see if it reaches the exit
        // rank of the block.
        block = defBlock and
        variableLiveOnExitFromBlock(vvar, defBlock) and
        definitionReachesRank(vvar, defBlock, defRank, exitRank(vvar, defBlock))
      ) or
      exists(OldIR::IRBlock idom |
        definitionReachesEndOfBlock(vvar, defBlock, defRank, idom) and
        noDefinitionsSinceIDominator(vvar, idom, block)
      )
    )
  }

  pragma[noinline]
  private predicate noDefinitionsSinceIDominator(Alias::VirtualVariable vvar,
    OldIR::IRBlock idom, OldIR::IRBlock block) {
    idom.immediatelyDominates(block) and // It is sufficient to traverse the dominator graph, cf. discussion above.
    variableLiveOnExitFromBlock(vvar, block) and
    not hasDefinition(vvar, block, _)
  }

  private predicate definitionReachesUseWithinBlock(
    Alias::VirtualVariable vvar, OldIR::IRBlock defBlock, int defRank, 
    OldIR::IRBlock useBlock, int useRank) {
    defBlock = useBlock and
    hasDefinitionAtRank(vvar, defBlock, defRank, _) and
    hasUseAtRank(vvar, useBlock, useRank, _) and
    definitionReachesRank(vvar, defBlock, defRank, useRank)
  }

  private predicate definitionReachesUse(Alias::VirtualVariable vvar,
    OldIR::IRBlock defBlock, int defRank, OldIR::IRBlock useBlock, int useRank) {
    hasUseAtRank(vvar, useBlock, useRank, _) and
    (
      definitionReachesUseWithinBlock(vvar, defBlock, defRank, useBlock,
        useRank) or
      (
        definitionReachesEndOfBlock(vvar, defBlock, defRank,
          useBlock.getAPredecessor()) and
        not definitionReachesUseWithinBlock(vvar, useBlock, _, useBlock, useRank)
      )
    )
  }

  private predicate hasFrontierPhiNode(Alias::VirtualVariable vvar, 
    OldIR::IRBlock phiBlock) {
    exists(OldIR::IRBlock defBlock |
      phiBlock = defBlock.dominanceFrontier() and
      hasDefinition(vvar, defBlock, _) and
      /* We can also eliminate those nodes where the variable is not live on any incoming edge */
      variableLiveOnEntryToBlock(vvar, phiBlock)
    )
  }

  private predicate hasPhiNode(Alias::VirtualVariable vvar,
    OldIR::IRBlock phiBlock) {
    hasFrontierPhiNode(vvar, phiBlock)
    //or ssa_sanitized_custom_phi_node(vvar, block)
  }
  
  private predicate hasChiNode(Alias::VirtualVariable vvar,
    OldIR::Instruction def) {
    exists(Alias::MemoryAccess ma |
      ma = Alias::getResultMemoryAccess(def) and
      ma.isPartialMemoryAccess() and
      ma.getVirtualVariable() = vvar
    ) and
    not def instanceof OldIR::UnmodeledDefinitionInstruction
  }
}

import CachedForDebugging
cached private module CachedForDebugging {
  cached string getTempVariableUniqueId(IRTempVariable var) {
    result = getOldTempVariable(var).getUniqueId()
  }

  cached string getInstructionUniqueId(Instruction instr) {
    exists(OldIR::Instruction oldInstr |
      oldInstr = getOldInstruction(instr) and
      result = "NonSSA: " + oldInstr.getUniqueId()
    ) or
    exists(Alias::VirtualVariable vvar, OldIR::IRBlock phiBlock |
      instr.getTag() = PhiTag(vvar, phiBlock) and
      result = "Phi Block(" + phiBlock.getUniqueId() + "): " + vvar.getUniqueId() 
    )
  }

  private OldIR::IRTempVariable getOldTempVariable(IRTempVariable var) {
    result.getFunction() = var.getFunction() and
    result.getAST() = var.getAST() and
    result.getTag() = var.getTag()
  }
}
