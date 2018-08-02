/**
 * INTERNAL: Do not use directly; use `semmle.javascript.dataflow.TypeInference` instead.
 *
 * Provides classes implementing type inference for most expressions, except for variable
 * and property accesses.
 */

import javascript
private import AbstractValuesImpl
private import semmle.javascript.dataflow.InferredTypes

/**
 * Flow analysis for literal expressions.
 */
private class AnalyzedLiteral extends DataFlow::AnalyzedValueNode {
  override Literal astNode;

  override AbstractValue getALocalValue() {
    exists (string value | value = astNode.getValue() |
      // flow analysis for `null` literals
      astNode instanceof NullLiteral and result = TAbstractNull()
      or
      // flow analysis for Boolean literals
      astNode instanceof BooleanLiteral and (
        value = "true" and result = TAbstractBoolean(true) or
        value = "false" and result = TAbstractBoolean(false)
      )
      or
      // flow analysis for number literals
      (astNode instanceof NumberLiteral or astNode instanceof BigIntLiteral) and
      exists (float fv | fv = value.toFloat() |
        if fv = 0.0 or fv = -0.0 then
          result = TAbstractZero()
        else
          result = TAbstractNonZero()
      )
      or
      // flow analysis for string literals
      astNode instanceof StringLiteral and
      (
        if value = "" then
          result = TAbstractEmpty()
        else if exists(value.toFloat()) then
          result = TAbstractNumString()
        else
          result = TAbstractOtherString()
      )
      or
      // flow analysis for regular expression literals
      astNode instanceof RegExpLiteral and
      result = TAbstractRegExp()
    )
  }
}

/**
 * Flow analysis for template literals.
 */
private class AnalyzedTemplateLiteral extends DataFlow::AnalyzedValueNode {
  override TemplateLiteral astNode;

  override AbstractValue getALocalValue() { result = abstractValueOfType(TTString()) }
}

/**
 * Flow analysis for object expressions.
 */
private class AnalyzedObjectExpr extends DataFlow::AnalyzedValueNode {
  override ObjectExpr astNode;

  override AbstractValue getALocalValue() { result = TAbstractObjectLiteral(astNode) }
}

/**
 * Flow analysis for array expressions.
 */
private class AnalyzedArrayExpr extends DataFlow::AnalyzedValueNode {
  override ArrayExpr astNode;

  override AbstractValue getALocalValue() { result = TAbstractOtherObject() }
}

/**
 * Flow analysis for array comprehensions.
 */
private class AnalyzedArrayComprehensionExpr extends DataFlow::AnalyzedValueNode {
  override ArrayComprehensionExpr astNode;

  override AbstractValue getALocalValue() { result = TAbstractOtherObject() }
}

/**
 * Flow analysis for functions.
 */
private class AnalyzedFunction extends DataFlow::AnalyzedValueNode {
  override Function astNode;

  override AbstractValue getALocalValue() { result = TAbstractFunction(astNode) }
}

/**
 * Flow analysis for class declarations.
 */
private class AnalyzedClassDefinition extends DataFlow::AnalyzedValueNode {
  override ClassDefinition astNode;

  override AbstractValue getALocalValue() { result = TAbstractClass(astNode) }
}

/**
 * Flow analysis for namespace objects.
 */
private class AnalyzedNamespaceDeclaration extends DataFlow::AnalyzedValueNode {
  override NamespaceDeclaration astNode;

  override AbstractValue getALocalValue() {
    result = TAbstractOtherObject() and getPreviousValue().getBooleanValue() = false
    or
    result = getPreviousValue() and result.getBooleanValue() = true
  }

  AbstractValue getPreviousValue() {
    exists (AnalyzedSsaDefinition def |
      def.getVariable().getAUse() = astNode.getId() and
      result = def.getAnRhsValue()
    )
  }
}

/**
 * Flow analysis for enum objects.
 */
private class AnalyzedEnumDeclaration extends DataFlow::AnalyzedValueNode {
  override EnumDeclaration astNode;

  override AbstractValue getALocalValue() { result = TAbstractOtherObject() }
}

/**
 * Flow analysis for JSX elements and fragments.
 */
private class AnalyzedJSXNode extends DataFlow::AnalyzedValueNode {
  override JSXNode astNode;

  override AbstractValue getALocalValue() { result = TAbstractOtherObject() }
}

/**
 * Flow analysis for qualified JSX names.
 */
private class AnalyzedJSXQualifiedName extends DataFlow::AnalyzedValueNode {
  override JSXQualifiedName astNode;

  override AbstractValue getALocalValue() { result = TAbstractOtherObject() }
}

/**
 * Flow analysis for empty JSX expressions.
 */
private class AnalyzedJSXEmptyExpression extends DataFlow::AnalyzedValueNode{
  override JSXEmptyExpr astNode;

  override AbstractValue getALocalValue() { result = TAbstractUndefined() }
}

/**
 * Flow analysis for `super` in super constructor calls.
 */
private class AnalyzedSuperCall extends DataFlow::AnalyzedValueNode {
  AnalyzedSuperCall() {
    astNode = any(SuperCall sc).getCallee().stripParens()
  }

  override AbstractValue getALocalValue() {
    exists (MethodDefinition md, DataFlow::AnalyzedNode sup, AbstractValue supVal |
      md.getBody() = asExpr().getEnclosingFunction() and
      sup = md.getDeclaringClass().getSuperClass().analyze() and
      supVal = sup.getALocalValue() |
      // `extends null` is treated specially in a way that we cannot model
      if supVal instanceof AbstractNull then
        result = TIndefiniteFunctionOrClass("heap")
      else
        result = supVal
    )
  }
}

/**
 * Flow analysis for `new`.
 *
 * This conservatively handles the case where the callee is not known
 * precisely, or where the callee might return a non-primitive value.
 */
private class AnalyzedNewExpr extends DataFlow::AnalyzedValueNode {
  override NewExpr astNode;

  override AbstractValue getALocalValue() {
    isIndefinite() and
    (
      result = TIndefiniteFunctionOrClass("call") or
      result = TIndefiniteObject("call")
    )
  }

  /**
   * Holds if the callee is indefinite, or if the callee is the
   * constructor of a class with a superclass, or if the callee may
   * return an explicit value. In the latter two cases, the callee
   * may substitute a custom return value for the newly created
   * instance, which we cannot track.
   */
  private predicate isIndefinite() {
    exists (DataFlow::AnalyzedNode callee, AbstractValue calleeVal |
      callee = astNode.(NewExpr).getCallee().analyze() and
      calleeVal = callee.getALocalValue() |
      calleeVal.isIndefinite(_) or
      exists(calleeVal.(AbstractClass).getClass().getSuperClass()) or
      exists(calleeVal.(AbstractCallable).getFunction().getAReturnedExpr())
    )
  }
}

/**
 * Flow analysis for `new` expressions that create class/function instances.
 */
private class NewInstance extends DataFlow::AnalyzedValueNode{
  override NewExpr astNode;

  override AbstractValue getALocalValue() {
    exists (DataFlow::AnalyzedNode callee |
      callee = astNode.(NewExpr).getCallee().analyze() and
      result = TAbstractInstance(callee.getALocalValue())
    )
  }
}

/**
 * Flow analysis for (non-short circuiting) binary expressions.
 */
private class AnalyzedBinaryExpr extends DataFlow::AnalyzedValueNode {
  override BinaryExpr astNode;

  AnalyzedBinaryExpr() {
    not astNode instanceof LogicalBinaryExpr
  }

  override AbstractValue getALocalValue() {
    // most binary expressions are arithmetic expressions;
    // the logical ones have overriding definitions below
    result = abstractValueOfType(TTNumber())
  }
}

/**
 * Holds if `e` may hold a string value.
 */
private predicate maybeString(Expr e) {
  e.analyze().getAPrimitiveType() = TTString()
}

/**
 * Holds if `e` may hold a non-string value.
 */
private predicate maybeNonString(Expr e) {
  e.analyze().getAPrimitiveType() != TTString()
}

/**
 * Holds if `e` is a `+` or `+=` expression that could be interpreted as a string append
 * (as opposed to a numeric addition) at runtime.
 */
private predicate isStringAppend(Expr e) {
  (e instanceof AddExpr or e instanceof AssignAddExpr) and
  maybeString(e.getAChildExpr())
}

/**
 * Holds if `e` is a `+` or `+=` expression that could be interpreted as a numeric addition
 * (as opposed to a string append) at runtime.
 */
private predicate isAddition(Expr e) {
  (e instanceof AddExpr or e instanceof AssignAddExpr) and
  maybeNonString(e.getChildExpr(0)) and maybeNonString(e.getChildExpr(1))
}

/**
 * Flow analysis for addition.
 */
private class AnalyzedAddExpr extends AnalyzedBinaryExpr {
  override AddExpr astNode;

  override AbstractValue getALocalValue() {
    isStringAppend(astNode) and result = abstractValueOfType(TTString()) or
    isAddition(astNode) and result = abstractValueOfType(TTNumber())
  }
}

/**
 * Flow analysis for comparison expressions.
 */
private class AnalyzedComparison extends AnalyzedBinaryExpr {
  override Comparison astNode;

  override AbstractValue getALocalValue() { result = TAbstractBoolean(_) }
}

/**
 * Flow analysis for `in` expressions.
 */
private class AnalyzedInExpr extends AnalyzedBinaryExpr  {
  override InExpr astNode;

  override AbstractValue getALocalValue() { result = TAbstractBoolean(_) }
}

/**
 * Flow analysis for `instanceof` expressions.
 */
private class AnalyzedInstanceofExpr extends AnalyzedBinaryExpr {
  override InstanceofExpr astNode;

  override AbstractValue getALocalValue() { result = TAbstractBoolean(_) }
}


/**
 * Flow analysis for unary expressions (except for spread, which is not
 * semantically a unary expression).
 */
private class AnalyzedUnaryExpr extends DataFlow::AnalyzedValueNode {
  override UnaryExpr astNode;

  AnalyzedUnaryExpr() {
    not astNode instanceof SpreadElement
  }

  override AbstractValue getALocalValue() {
    // many unary expressions are arithmetic expressions;
    // the others have overriding definitions below
    result = abstractValueOfType(TTNumber())
  }
}

/**
 * Flow analysis for `void` expressions.
 */
private class AnalyzedVoidExpr extends AnalyzedUnaryExpr {
  override VoidExpr astNode;

  override AbstractValue getALocalValue() { result = TAbstractUndefined() }
}

/**
 * Flow analysis for `typeof` expressions.
 */
private class AnalyzedTypeofExpr extends AnalyzedUnaryExpr {
  override TypeofExpr astNode;

  override AbstractValue getALocalValue() { result = TAbstractOtherString() }
}

/**
 * Flow analysis for logical negation.
 */
private class AnalyzedLogNotExpr extends AnalyzedUnaryExpr {
  override LogNotExpr astNode;

  override AbstractValue getALocalValue() {
    exists (AbstractValue op | op = astNode.getOperand().analyze().getALocalValue() |
      exists (boolean bv | bv = op.getBooleanValue() |
        bv = true and result = TAbstractBoolean(false) or
        bv = false and result = TAbstractBoolean(true)
      )
    )
  }
}

/**
 * Flow analysis for `delete` expressions.
 */
private class AnalyzedDeleteExpr extends AnalyzedUnaryExpr {
  override DeleteExpr astNode;

  override AbstractValue getALocalValue() { result = TAbstractBoolean(_) }
}


/**
 * Flow analysis for increment and decrement expressions.
 */
private class AnalyzedUpdateExpr extends DataFlow::AnalyzedValueNode {
  override UpdateExpr astNode;

  override AbstractValue getALocalValue() { result = abstractValueOfType(TTNumber()) }
}


/**
 * Flow analysis for compound assignments.
 */
private class AnalyzedCompoundAssignExpr extends DataFlow::AnalyzedValueNode {
  override CompoundAssignExpr astNode;

  override AbstractValue getALocalValue() { result = abstractValueOfType(TTNumber()) }
}

/**
 * Flow analysis for add-assign.
 */
private class AnalyzedAssignAddExpr extends AnalyzedCompoundAssignExpr {
  override AssignAddExpr astNode;

  override AbstractValue getALocalValue() {
    isStringAppend(astNode) and result = abstractValueOfType(TTString()) or
    isAddition(astNode) and result = abstractValueOfType(TTNumber())
  }
}
