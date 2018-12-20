import csharp
import ControlFlow::Internal::PreBasicBlocks

predicate bbStartInconsistency(ControlFlowElement cfe) {
  exists(ControlFlow::BasicBlock bb | bb.getFirstNode() = cfe.getAControlFlowNode()) and
  not cfe = any(PreBasicBlock bb).getFirstElement()
}

predicate bbSuccInconsistency(ControlFlowElement pred, ControlFlowElement succ) {
  exists(ControlFlow::BasicBlock predBB, ControlFlow::BasicBlock succBB |
    predBB.getLastNode() = pred.getAControlFlowNode() and
    succBB = predBB.getASuccessor() and
    succBB.getFirstNode() = succ.getAControlFlowNode()
  ) and
  not exists(PreBasicBlock predBB, PreBasicBlock succBB |
    predBB.getLastElement() = pred and
    succBB = predBB.getASuccessor() and
    succBB.getFirstElement() = succ
  )
}

predicate bbIntraSuccInconsistency(ControlFlowElement pred, ControlFlowElement succ) {
  exists(ControlFlow::BasicBlock bb, int i |
    pred.getAControlFlowNode() = bb.getNode(i) and
    succ.getAControlFlowNode() = bb.getNode(i + 1)
  ) and
  not exists(PreBasicBlock bb |
    bb.getLastElement() = pred and
    bb.getASuccessor().getFirstElement() = succ
  ) and
  not exists(PreBasicBlock bb, int i |
    bb.getElement(i) = pred and
    bb.getElement(i + 1) = succ
  )
}

from ControlFlowElement cfe1, ControlFlowElement cfe2, string s
where
  bbStartInconsistency(cfe1) and
  cfe2 = cfe1 and
  s = "start inconsistency"
  or
  bbSuccInconsistency(cfe1, cfe2) and
  s = "succ inconsistency"
  or
  bbIntraSuccInconsistency(cfe1, cfe2) and
  s = "intra succ inconsistency"
select cfe1, cfe2, s
