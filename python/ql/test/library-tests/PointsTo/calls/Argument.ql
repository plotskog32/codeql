import python

from ControlFlowNode arg, FunctionValue func, int i
where arg = func.getArgumentForCall(_, i)
select arg.getLocation().getStartLine(), i, arg.toString(), func.toString()
