import csharp
import ControlFlow::Internal
private import semmle.code.csharp.controlflow.Completion

from ControlFlowElement cfe, Completion c
select cfe, last(cfe, c), c
