import csharp
import Common

predicate step(DataFlow::Node pred, DataFlow::Node succ) {
  DataFlow::localFlowStep(pred, succ) and
  not succ instanceof MyNullGuardedDataFlowNode
}

from MyFlowSource source, DataFlow::Node sink, Access target
where
  step+(source, sink) and
  sink = DataFlow::exprNode(target) and
  exists(MethodCall mc | mc.getTarget().getName() = "Check" and mc.getAnArgument() = target)
select sink
