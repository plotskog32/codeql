/**
 * @name Modification of dictionary returned by locals()
 * @description Modifications of the dictionary returned by locals() are not propagated to the local variables of a function.
 * @kind problem
 * @tags reliability
 *       correctness
 * @problem.severity warning
 * @sub-severity low
 * @precision very-high
 * @id py/modification-of-locals
 */

import python

predicate originIsLocals(ControlFlowNode n) {
    n.pointsTo(_, _, Value::named("locals").getACall())
}

predicate modification_of_locals(ControlFlowNode f) {
    originIsLocals(f.(SubscriptNode).getObject()) and
    (f.isStore() or f.isDelete())
    or
    exists(string mname, AttrNode attr |
        attr = f.(CallNode).getFunction() and
        originIsLocals(attr.getObject(mname))
    |
        mname = "pop" or
        mname = "popitem" or
        mname = "update" or
        mname = "clear"
    )
}

from AstNode a, ControlFlowNode f
where modification_of_locals(f) and a = f.getNode()
select a, "Modification of the locals() dictionary will have no effect on the local variables."
