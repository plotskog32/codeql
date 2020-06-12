import python
private import DataFlowPrivate

/**
 * An element, viewed as a node in a data flow graph. Either an expression
 * (`ExprNode`) or a parameter (`ParameterNode`).
 */
class Node extends ControlFlowNode {
  /** Gets the enclosing callable of this node. */
  final DataFlowCallable getEnclosingCallable() {
    none()
  }

  /**
   * Gets an upper bound on the type of this node.
   */
  DataFlowType getTypeBound() {
    none()
  }

  /**
   * Holds if this element is at the specified location.
   * The location spans column `startcolumn` of line `startline` to
   * column `endcolumn` of line `endline` in file `filepath`.
   * For more information, see
   * [Locations](https://help.semmle.com/QL/learn-ql/ql/locations.html).
   */
  predicate hasLocationInfo(
    string filepath, int startline, int startcolumn, int endline, int endcolumn
  ) {
    getLocation().hasLocationInfo(filepath, startline, startcolumn, endline, endcolumn)
  }

}

/**
 * An expression, viewed as a node in a data flow graph.
 *
 * Note that because of control-flow splitting, one `Expr` may correspond
 * to multiple `ExprNode`s, just like it may correspond to multiple
 * `ControlFlow::Node`s.
 */
class ExprNode extends Node {
}

/** Gets a node corresponding to expression `e`. */
ExprNode exprNode(DataFlowExpr e) { none() }

/**
 * The value of a parameter at function entry, viewed as a node in a data
 * flow graph.
 */
class ParameterNode extends Node {
    /**
   * Holds if this node is the parameter of callable `c` at the specified
   * (zero-based) position.
   */
  predicate isParameterOf(DataFlowCallable c, int i) { none() }
}

/**
 * A guard that validates some expression.
 *
 * To use this in a configuration, extend the class and provide a
 * characteristic predicate precisely specifying the guard, and override
 * `checks` to specify what is being validated and in which branch.
 *
 * It is important that all extending classes in scope are disjoint.
 */
class BarrierGuard extends Expr {
  /** Holds if this guard validates `e` upon evaluating to `v`. */
  // abstract predicate checks(Expr e, AbstractValue v);

  /** Gets a node guarded by this guard. */
  final ExprNode getAGuardedNode() {
    none()
    // exists(Expr e, AbstractValue v |
    //   this.checks(e, v) and
    //   this.controlsNode(result.getControlFlowNode(), e, v)
    // )
  }
}

/**
 * A reference contained in an object. This is either a field or a property.
 */
class Content extends string {
  Content() { this = "Content" }

  /** Gets the type of the object containing this content. */
  DataFlowType getContainerType() { none() }

  /** Gets the type of this content. */
  DataFlowType getType() { none() }
}