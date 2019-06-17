/**
 * @name Upcast array used in pointer arithmetic
 * @description An array with elements of a derived struct type is cast to a
 *              pointer to the base type of the struct. If pointer arithmetic or
 *              an array dereference is done on the resulting pointer, it will
 *              use the width of the base type, leading to misaligned reads.
 * @kind path-problem
 * @problem.severity warning
 * @precision high
 * @tags correctness
 *       reliability
 *       security
 *       external/cwe/cwe-119
 *       external/cwe/cwe-843
 * @id cpp/upcast-array-pointer-arithmetic
 */

import cpp
import semmle.code.cpp.dataflow.DataFlow
import DataFlow::PathGraph

class CastToPointerArithFlow extends DataFlow::Configuration {
  CastToPointerArithFlow() {
    this = "CastToPointerArithFlow"
  }

  override predicate isSource(DataFlow::Node node) {
    not node.asExpr() instanceof Conversion and
    introducesNewField(
      node.asExpr().getType().(DerivedType).getBaseType(),
      node.asExpr().getConversion*().getType().(DerivedType).getBaseType()
      
    )
  }

  override predicate isSink(DataFlow::Node node) {
    exists(PointerAddExpr pae |
      pae.getAnOperand() = node.asExpr()
    ) or
    exists(ArrayExpr ae |
      ae.getArrayBase() = node.asExpr()
    )
  }
}

/**
 * `derived` has a (possibly indirect) base class of `base`, and `derived`
 * introduces at least one new field that isn't in a base class.
 */
predicate introducesNewField(Class derived, Class base) {
  (
    exists(Field f |
      f.getDeclaringType() = derived and
      derived.getABaseClass+() = base
    ) or
    introducesNewField(derived.getABaseClass(), base)
  )
}

from DataFlow::PathNode source, DataFlow::PathNode sink, CastToPointerArithFlow cfg
where cfg.hasFlowPath(source, sink)
  and source.getNode().asExpr().getFullyConverted().getUnspecifiedType() = sink.getNode().asExpr().getFullyConverted().getUnspecifiedType()
select sink, source, sink, "Pointer arithmetic here may be done with the wrong type because of the cast $@.", source, "here"
