/**
 * Provides classes for working with JSX code.
 */

import javascript

/**
 * A JSX element or fragment.
 */
class JSXNode extends Expr, @jsxelement {
  /** Gets the `i`th element in the body of this element or fragment. */
  Expr getBodyElement(int i) {
    i >= 0 and result = getChildExpr(-i-2)
  }

  /** Gets an element in the body of this element or fragment. */
  Expr getABodyElement() {
    result = getBodyElement(_)
  }

  /**
   * Gets the parent JSX element or fragment of this element.
   */
  JSXNode getJsxParent() {
    this = result.getABodyElement()
  }
}

/**
 * A JSX element such as `<a href={linkTarget()}>{linkText()}</a>`.
 */
class JSXElement extends JSXNode {
  JSXName name;

  JSXElement() {
    name = getChildExpr(-1)
  }

  /** Gets the expression denoting the name of this element. */
  JSXName getNameExpr() {
    result = name
  }

  /** Gets the name of this element. */
  string getName() {
    result = name.getValue()
  }

  /** Gets the `i`th attribute of this element. */
  JSXAttribute getAttribute(int i) {
    properties(result, this, i, _, _)
  }

  /** Gets an attribute of this element. */
  JSXAttribute getAnAttribute() {
    result = getAttribute(_)
  }

  /** Gets the attribute of this element with the given name, if any. */
  JSXAttribute getAttributeByName(string n) {
    result = getAnAttribute() and result.getName() = n
  }

  override ControlFlowNode getFirstControlFlowNode() {
    result = getNameExpr().getFirstControlFlowNode()
  }
}

/**
 * A JSX fragment such as `<><h1>Title</h1>Some <b>text</b></>`.
 */
class JSXFragment extends JSXNode {
  JSXFragment() {
    not exists(getChildExpr(-1))
  }

  override ControlFlowNode getFirstControlFlowNode() {
    result = getBodyElement(0).getFirstControlFlowNode() or
    not exists(getABodyElement()) and result = this
  }
}

/**
 * An attribute of a JSX element such as `href={linkTarget()}` or `{...attrs}`.
 */
class JSXAttribute extends ASTNode, @jsx_attribute {
  /**
   * Gets the expression denoting the name of this attribute.
   *
   * This is not defined for spread attributes.
   */
  JSXName getNameExpr() {
    result = getChildExpr(0)
  }

  /**
   * Gets the name of this attribute.
   *
   * This is not defined for spread attributes.
   */
  string getName() {
    result = getNameExpr().getValue()
  }

  /** Gets the expression denoting the value of this attribute. */
  Expr getValue() {
    result = getChildExpr(1)
  }

  /** Gets the value of this attribute as a constant string, if possible. */
  string getStringValue() {
    result = getValue().getStringValue()
  }

  /** Gets the JSX element to which this attribute belongs. */
  JSXElement getElement() {
    this = result.getAnAttribute()
  }

  override ControlFlowNode getFirstControlFlowNode() {
    result = getNameExpr().getFirstControlFlowNode() or
    not exists(getNameExpr()) and result = getValue().getFirstControlFlowNode()
  }

  override string toString() {
    properties(this, _, _, _, result)
  }
}

/**
 * A spread attribute of a JSX element, such as `{...attrs}`.
 */
class JSXSpreadAttribute extends JSXAttribute {
  JSXSpreadAttribute() { not exists(getNameExpr()) }

  override SpreadElement getValue() {
    // override for more precise result type
    result = super.getValue()
  }
}

/**
 * A namespace-qualified name such as `n:a`.
 */
class JSXQualifiedName extends Expr, @jsxqualifiedname {
  /** Gets the namespace component of this qualified name. */
  Identifier getNamespace() {
    result = getChildExpr(0)
  }

  /** Gets the name component of this qualified name. */
  Identifier getName() {
    result = getChildExpr(1)
  }

  override ControlFlowNode getFirstControlFlowNode() {
    result = getNamespace().getFirstControlFlowNode()
  }
}

/**
 * A name of an JSX element or attribute (which is
 * always an identifier, a dot expression, or a qualified
 * namespace name).
 */
class JSXName extends Expr {
  JSXName() {
    this instanceof Identifier or
    this.(DotExpr).getBase() instanceof JSXName or
    this instanceof JSXQualifiedName
  }

  /**
   * Gets the string value of this name.
   */
  string getValue() {
    result = this.(Identifier).getName() or
    exists (DotExpr dot | dot = this |
      result = dot.getBase().(JSXName).getValue() + "." + dot.getPropertyName()
    ) or
    exists (JSXQualifiedName qual | qual = this |
      result = qual.getNamespace() + ":" + qual.getName()
    )
  }
}

/**
 * An interpolating expression that interpolates nothing.
 */
class JSXEmptyExpr extends Expr, @jsxemptyexpr {
}

/**
 * A legacy `@jsx` pragma such as `@jsx React.DOM`.
 */
class JSXPragma extends JSDocTag {
  JSXPragma() {
    getTitle() = "jsx"
  }

  /**
   * Gets the DOM name specified by the pragma; for `@jsx React.DOM`,
   * the result is `React.DOM`.
   */
  string getDOMName() {
    result = getDescription().trim()
  }
}
