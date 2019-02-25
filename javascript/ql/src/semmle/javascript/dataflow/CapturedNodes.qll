/**
 * Provides classes for the nodes that the dataflow library can reason about soundly.
 */

import javascript

/**
 * Holds if the dataflow library can not track flow through `escape` due to `cause`.
 */
private predicate isEscape(DataFlow::Node escape, string cause) {
  escape = any(DataFlow::InvokeNode invk).getAnArgument() and cause = "argument"
  or
  escape = any(DataFlow::FunctionNode fun).getAReturn() and cause = "return"
  or
  escape = any(ThrowStmt t).getExpr().flow() and cause = "throw"
  or
  escape = any(DataFlow::GlobalVariable v).getAnAssignedExpr().flow() and cause = "global"
  or
  escape = any(DataFlow::PropWrite write).getRhs() and cause = "heap"
  or
  escape = any(ExportDeclaration e).getSourceNode(_) and cause = "export"
  or
  any(WithStmt with).mayAffect(escape.asExpr()) and cause = "heap"
}

private DataFlow::Node getAnEscape() {
  isEscape(result, _)
}

/**
 * Holds if `n` can flow to a `this`-variable.
 */
private predicate exposedAsReceiver(DataFlow::SourceNode n) {
  // pragmatic limitation: guarantee for object literals only
  not n instanceof DataFlow::ObjectLiteralNode
  or
  exists(AbstractValue v | n.getAPropertyWrite().getRhs().analyze().getALocalValue() = v |
    v.isIndefinite(_) or
    exists(ThisExpr dis | dis.getBinder() = v.(AbstractCallable).getFunction())
  )
  or
  n.flowsToExpr(any(FunctionBindExpr bind).getObject())
  or
  // technically, the builtin prototypes could have a `this`-using function through which this node escapes, but we ignore that here
  // (we also ignore `o['__' + 'proto__'] = ...`)
  exists(n.getAPropertyWrite("__proto__"))
  or
  // could check the assigned value of all affected variables, but it is unlikely to matter in practice
  exists(WithStmt with | n.flowsToExpr(with.getExpr()))
}

/**
 * A source for which the flow is entirely captured by the dataflow library.
 * All uses of the node are modeled by `this.flowsTo(_)` and related predicates.
 */
class CapturedSource extends DataFlow::SourceNode {
  CapturedSource() {
    // pragmatic limitation: object literals only
    this instanceof DataFlow::ObjectLiteralNode and
    not flowsTo(getAnEscape()) and
    not exposedAsReceiver(this)
  }

  predicate hasOwnProperty(string name) {
    // the property is defined in the initializer,
    any(DataFlow::PropWrite write).writes(this, name, _) and
    // and it is never deleted
    not exists(DeleteExpr del, DataFlow::PropRef ref |
      del.getOperand().flow() = ref and
      flowsTo(ref.getBase()) and
      (ref.getPropertyName() = name or not exists(ref.getPropertyName()))
    )
  }
}
