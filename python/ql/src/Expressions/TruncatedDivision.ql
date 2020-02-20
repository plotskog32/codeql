 /**
  * @name Result of integer division may be truncated
  * @description The arguments to a division statement may be integers, which
  *              may cause the result to be truncated in Python 2.
  * @kind problem
  * @tags maintainability
  *       correctness
  * @problem.severity warning
  * @sub-severity high
  * @precision very-high
  * @id py/truncated-division
  */

import python

from BinaryExpr div, ControlFlowNode left, ControlFlowNode right
where
    // Only relevant for Python 2, as all later versions implement true division
    major_version() = 2
    and
    exists(BinaryExprNode bin, Value lobj, Value robj |
        bin = div.getAFlowNode()
        and bin.getNode().getOp() instanceof Div
        and bin.getLeft().pointsTo(lobj, left)
        and lobj.getClass() = ClassValue::int_()
        and bin.getRight().pointsTo(robj, right)
        and robj.getClass() = ClassValue::int_()
        // Ignore instances where integer division leaves no remainder
        and not lobj.(NumericValue).intValue() % robj.(NumericValue).intValue() = 0
        and not bin.getNode().getEnclosingModule().hasFromFuture("division")
        // Filter out results wrapped in `int(...)`
        and not exists(CallNode c, ClassValue cls |
            c.getAnArg() = bin
            and c.getFunction().pointsTo(cls)
            and cls.getName() = "int"
        )
    )
select div, "Result of division may be truncated as its $@ and $@ arguments may both be integers.",
       left.getLocation(), "left", right.getLocation(), "right"
