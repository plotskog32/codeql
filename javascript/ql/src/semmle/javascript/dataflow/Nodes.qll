/**
 * Provides classes representing particular kinds of data flow nodes, such
 * as nodes corresponding to function definitions or nodes corresponding to
 * parameters.
 */

private import javascript
private import semmle.javascript.dependencies.Dependencies

/** A data flow node corresponding to an expression. */
class ExprNode extends DataFlow::ValueNode {
  override Expr astNode;
}

/** A data flow node corresponding to a parameter. */
class ParameterNode extends DataFlow::SourceNode {
  Parameter p;

  ParameterNode() { DataFlow::parameterNode(this, p) }

  /** Gets the parameter to which this data flow node corresponds. */
  Parameter getParameter() { result = p }

  /** Gets the name of this parameter. */
  string getName() { result = p.getName() }

  /** Holds if this parameter is a rest parameter. */
  predicate isRestParameter() { p.isRestParameter() }
}

/** A data flow node corresponding to a function invocation (with or without `new`). */
class InvokeNode extends DataFlow::SourceNode {
  DataFlow::Impl::InvokeNodeDef impl;

  InvokeNode() { this = impl }

  /** Gets the syntactic invoke expression underlying this function invocation. */
  InvokeExpr getInvokeExpr() { result = impl.getInvokeExpr() }

  /** Gets the name of the function or method being invoked, if it can be determined. */
  string getCalleeName() { result = impl.getCalleeName() }

  /** Gets the data flow node specifying the function to be called. */
  DataFlow::Node getCalleeNode() { result = impl.getCalleeNode() }

  /**
   * Gets the data flow node corresponding to the `i`th argument of this invocation.
   *
   * For direct calls, this is the `i`th argument to the call itself: for instance,
   * for a call `f(x, y)`, the 0th argument node is `x` and the first argument node is `y`.
   *
   * For reflective calls using `call`, the 0th argument to the call denotes the
   * receiver, so argument positions are shifted by one: for instance, for a call
   * `f.call(x, y, z)`, the 0th argument node is `y` and the first argument node is `z`,
   * while `x` is not an argument node at all.
   *
   * For reflective calls using `apply` we cannot, in general, tell which argument
   * occurs at which position, so this predicate is not defined for such calls.
   *
   * Note that this predicate is not defined for arguments following a spread
   * argument: for instance, for a call `f(x, ...y, z)`, the 0th argument node is `x`,
   * but the position of `z` cannot be determined, hence there are no first and second
   * argument nodes.
   */
  DataFlow::Node getArgument(int i) { result = impl.getArgument(i) }

  /** Gets the data flow node corresponding to an argument of this invocation. */
  DataFlow::Node getAnArgument() { result = impl.getAnArgument() }

  /** Gets the data flow node corresponding to the last argument of this invocation. */
  DataFlow::Node getLastArgument() { result = getArgument(getNumArgument() - 1) }

  /**
   * Gets a data flow node corresponding to an array of values being passed as
   * individual arguments to this invocation.
   *
   * Examples:
   * ```
   * x.push(...args);                     // 'args' is a spread argument
   * x.push(x, ...args, y, ...more);      // 'args' and 'more' are a spread arguments
   * Array.prototype.push.apply(x, args); // 'args' is a spread argument
   * ```
   *  .
   */
  DataFlow::Node getASpreadArgument() { result = impl.getASpreadArgument() }

  /** Gets the number of arguments of this invocation, if it can be determined. */
  int getNumArgument() { result = impl.getNumArgument() }

  Function getEnclosingFunction() { result = getBasicBlock().getContainer() }

  /** Gets a function passed as the `i`th argument of this invocation. */
  FunctionNode getCallback(int i) { result.flowsTo(getArgument(i)) }

  /**
   * Holds if the `i`th argument of this invocation is an object literal whose property
   * `name` is set to `result`.
   */
  DataFlow::ValueNode getOptionArgument(int i, string name) {
    exists(ObjectLiteralNode obj |
      obj.flowsTo(getArgument(i)) and
      obj.hasPropertyWrite(name, result)
    )
  }

  /** Gets an abstract value representing possible callees of this call site. */
  final AbstractValue getACalleeValue() { result = getCalleeNode().analyze().getAValue() }

  /**
   * Gets a potential callee of this call site.
   *
   * To alter the call graph as seen by the interprocedural data flow libraries, override
   * the `getACallee(int imprecision)` predicate instead.
   */
  final Function getACallee() { result = getACallee(_) }

  /**
   * Gets a callee of this call site where `imprecision` is a heuristic measure of how
   * likely it is that `callee` is only suggested as a potential callee due to
   * imprecise analysis of global variables and is not, in fact, a viable callee at all.
   *
   * Callees with imprecision zero, in particular, have either been derived without
   * considering global variables, or are calls to a global variable within the same file.
   *
   * This predicate can be overridden to alter the call graph used by the interprocedural
   * data flow libraries.
   */
  cached
  Function getACallee(int imprecision) {
    result.flow() = getCalleeNode().getAFunctionValue(imprecision)
    or
    imprecision = 0 and
    exists(InvokeExpr expr | expr = this.(DataFlow::Impl::ExplicitInvokeNode).asExpr() |
      result = expr.getResolvedCallee()
      or
      exists(DataFlow::ClassNode cls |
        expr.(SuperCall).getBinder() = cls.getAnInstanceMethodOrConstructor().getFunction() and
        result = cls.getADirectSuperClass().getConstructor().getFunction()
      )
    )
  }

  /**
   * Holds if the approximation of possible callees for this call site is
   * affected by the given analysis incompleteness `cause`.
   */
  predicate isIndefinite(DataFlow::Incompleteness cause) { getACalleeValue().isIndefinite(cause) }

  /**
   * Holds if our approximation of possible callees for this call site is
   * likely to be imprecise.
   *
   * We currently track one specific source of imprecision: call
   * resolution relies on flow through global variables, and the flow
   * analysis finds possible callees that are not functions.
   * This usually means that a global variable is used in multiple
   * independent contexts, so tracking flow through it leads to
   * imprecision.
   */
  predicate isImprecise() {
    isIndefinite("global") and
    exists(DefiniteAbstractValue v | v = getACalleeValue() | not v instanceof AbstractCallable)
  }

  /**
   * Holds if our approximation of possible callees for this call site is
   * likely to be incomplete.
   */
  predicate isIncomplete() {
    // the flow analysis identifies a source of incompleteness other than
    // global flow (which usually leads to imprecision rather than incompleteness)
    any(DataFlow::Incompleteness cause | isIndefinite(cause)) != "global"
  }

  /**
   * Holds if our approximation of possible callees for this call site is
   * likely to be imprecise or incomplete.
   */
  predicate isUncertain() { isImprecise() or isIncomplete() }

  /**
   * Gets the data flow node representing an exception thrown from this invocation.
   */
  DataFlow::ExceptionalInvocationReturnNode getExceptionalReturn() {
    DataFlow::exceptionalInvocationReturnNode(result, asExpr())
  }
}

/** A data flow node corresponding to a function call without `new`. */
class CallNode extends InvokeNode {
  override DataFlow::Impl::CallNodeDef impl;

  /**
   * Gets the data flow node corresponding to the receiver expression of this method call.
   *
   * For example, the receiver of `x.m()` is `x`.
   */
  DataFlow::Node getReceiver() { result = impl.getReceiver() }
}

/** A data flow node corresponding to a method call. */
class MethodCallNode extends CallNode {
  override DataFlow::Impl::MethodCallNodeDef impl;

  /** Gets the name of the invoked method, if it can be determined. */
  string getMethodName() { result = impl.getMethodName() }

  /**
   * Holds if this data flow node calls method `methodName` on receiver node `receiver`.
   */
  predicate calls(DataFlow::Node receiver, string methodName) {
    receiver = getReceiver() and
    methodName = getMethodName()
  }
}

/** A data flow node corresponding to a `new` expression. */
class NewNode extends InvokeNode {
  override DataFlow::Impl::NewNodeDef impl;
}

/** A data flow node corresponding to the `this` parameter in a function or `this` at the top-level. */
class ThisNode extends DataFlow::Node, DataFlow::SourceNode {
  ThisNode() { DataFlow::thisNode(this, _) }

  /**
   * Gets the function whose `this` binding this expression refers to,
   * which is the nearest enclosing non-arrow function.
   */
  FunctionNode getBinder() {
    exists(Function binder |
      DataFlow::thisNode(this, binder) and
      result = DataFlow::valueNode(binder)
    )
  }

  /**
   * Gets the function or top-level whose `this` binding this expression refers to,
   * which is the nearest enclosing non-arrow function or top-level.
   */
  StmtContainer getBindingContainer() { DataFlow::thisNode(this, result) }
}

/** A data flow node corresponding to a global variable access. */
class GlobalVarRefNode extends DataFlow::ValueNode, DataFlow::SourceNode {
  override GlobalVarAccess astNode;

  /** Gets the name of the global variable. */
  string getName() { result = astNode.getName() }
}

/**
 * Gets a data flow node corresponding to an access to the global object, including
 * `this` expressions outside functions, references to global variables `window`
 * and `global`, and uses of the `global` npm package.
 */
DataFlow::SourceNode globalObjectRef() {
  // top-level `this`
  exists(StmtContainer sc |
    sc = result.(ThisNode).getBindingContainer() and
    not sc instanceof Function
  )
  or
  // DOM
  result = globalVarRef("window")
  or
  // Node.js
  result = globalVarRef("global")
  or
  // DOM and service workers
  result = globalVarRef("self")
  or
  // `require("global")`
  result = moduleImport("global")
  or
  // Closure library - based on AST to avoid recursion with Closure library model
  result = globalVarRef("goog").getAPropertyRead("global")
}

/**
 * Gets a data flow node corresponding to an access to global variable `name`,
 * either directly, through `window` or `global`, or through the `global` npm package.
 */
pragma[nomagic]
DataFlow::SourceNode globalVarRef(string name) {
  result.(GlobalVarRefNode).getName() = name
  or
  result = globalObjectRef().getAPropertyReference(name)
  or
  // `require("global/document")` or `require("global/window")`
  (name = "document" or name = "window") and
  result = moduleImport("global/" + name)
}

/** A data flow node corresponding to a function definition. */
class FunctionNode extends DataFlow::ValueNode, DataFlow::SourceNode {
  override Function astNode;

  /** Gets the `i`th parameter of this function. */
  ParameterNode getParameter(int i) { result = DataFlow::parameterNode(astNode.getParameter(i)) }

  /** Gets a parameter of this function. */
  ParameterNode getAParameter() { result = getParameter(_) }

  /** Gets the number of parameters declared on this function. */
  int getNumParameter() { result = count(astNode.getAParameter()) }

  /** Gets the last parameter of this function. */
  ParameterNode getLastParameter() { result = getParameter(getNumParameter() - 1) }

  /** Holds if the last parameter of this function is a rest parameter. */
  predicate hasRestParameter() { astNode.hasRestParameter() }

  /** Gets the unqualified name of this function, if it has one or one can be determined from the context. */
  string getName() { result = astNode.getName() }

  /** Gets a data flow node corresponding to a return value of this function. */
  DataFlow::Node getAReturn() { result = astNode.getAReturnedExpr().flow() }

  /**
   * Gets the function this node corresponds to.
   */
  Function getFunction() { result = astNode }

  /**
   * Gets the function whose `this` binding a `this` expression in this function refers to,
   * which is the nearest enclosing non-arrow function.
   */
  FunctionNode getThisBinder() { result.getFunction() = getFunction().getThisBinder() }

  /**
   * Gets the dataflow node holding the value of the receiver passed to the given function.
   *
   * Has no result for arrow functions, as they ignore the receiver argument.
   *
   * To get the data flow node for `this` in an arrow function, consider using `getThisBinder().getReceiver()`.
   */
  ThisNode getReceiver() { result.getBinder() = this }

  /**
   * Gets the data flow node representing an exception thrown from this function.
   */
  DataFlow::ExceptionalFunctionReturnNode getExceptionalReturn() {
    DataFlow::exceptionalFunctionReturnNode(result, astNode)
  }
}

/** A data flow node corresponding to an object literal expression. */
class ObjectLiteralNode extends DataFlow::ValueNode, DataFlow::SourceNode {
  override ObjectExpr astNode;
}

/** A data flow node corresponding to an array literal expression. */
class ArrayLiteralNode extends DataFlow::ValueNode, DataFlow::SourceNode {
  override ArrayExpr astNode;

  /** Gets the `i`th element of this array literal. */
  DataFlow::ValueNode getElement(int i) { result = DataFlow::valueNode(astNode.getElement(i)) }

  /** Gets an element of this array literal. */
  DataFlow::ValueNode getAnElement() { result = DataFlow::valueNode(astNode.getAnElement()) }

  /** Gets the initial size of this array. */
  int getSize() { result = astNode.getSize() }
}

/** A data flow node corresponding to a `new Array()` or `Array()` invocation. */
class ArrayConstructorInvokeNode extends DataFlow::InvokeNode {
  ArrayConstructorInvokeNode() { getCalleeNode() = DataFlow::globalVarRef("Array") }

  /** Gets the `i`th initial element of this array, if one is provided. */
  DataFlow::ValueNode getElement(int i) {
    getNumArgument() > 1 and // A single-argument invocation specifies the array length, not an element.
    result = getArgument(i)
  }

  /** Gets an initial element of this array, if one is provided. */
  DataFlow::ValueNode getAnElement() {
    getNumArgument() > 1 and
    result = getAnArgument()
  }

  /** Gets the initial size of the created array, if it can be determined. */
  int getSize() {
    if getNumArgument() = 1 then
      result = getArgument(0).getIntValue()
    else
      result = count(getAnElement())
  }
}

/**
 * A data flow node corresponding to the creation or a new array, either through an array literal
 * or an invocation of the `Array` constructor.
 */
class ArrayCreationNode extends DataFlow::ValueNode, DataFlow::SourceNode {
  ArrayCreationNode() {
    this instanceof ArrayLiteralNode or
    this instanceof ArrayConstructorInvokeNode
  }

  /** Gets the `i`th initial element of this array, if one is provided. */
  DataFlow::ValueNode getElement(int i) {
    result = this.(ArrayLiteralNode).getElement(i) or
    result = this.(ArrayConstructorInvokeNode).getElement(i)
  }

  /** Gets an initial element of this array, if one if provided. */
  DataFlow::ValueNode getAnElement() { result = getElement(_) }

  /** Gets the initial size of the created array, if it can be determined. */
  int getSize() {
    result = this.(ArrayLiteralNode).getSize() or
    result = this.(ArrayConstructorInvokeNode).getSize()
  }
}

/**
 * A data flow node corresponding to a `default` import from a module, or a
 * (AMD or CommonJS) `require` of a module.
 *
 * For compatibility with old transpilers, we treat `import * from '...'`
 * as a default import as well.
 *
 * Additional import nodes can be added by subclassing `ModuleImportNode::Range`.
 */
class ModuleImportNode extends DataFlow::SourceNode {
  ModuleImportNode::Range range;

  ModuleImportNode() { this = range }

  /** Gets the path of the imported module. */
  string getPath() { result = range.getPath() }
}

module ModuleImportNode {
  /**
   * A data flow node that refers to an imported module.
   */
  abstract class Range extends DataFlow::SourceNode {
    /** Gets the path of the imported module. */
    abstract string getPath();
  }

  private class DefaultRange extends Range {
    string path;

    DefaultRange() {
      exists(Import i |
        this = i.getImportedModuleNode() and
        i.getImportedPath().getValue() = path
      )
      or
      // AMD require
      exists(AmdModuleDefinition amd, CallExpr req |
        req = amd.getARequireCall() and
        this = DataFlow::valueNode(req) and
        path = req.getArgument(0).getStringValue()
      )
    }

    /** Gets the path of the imported module. */
    override string getPath() { result = path }
  }
}

/**
 * Gets a (default) import of the module with the given path, such as `require("fs")`
 * or `import * as fs from "fs"`.
 *
 * This predicate can be extended by subclassing `ModuleImportNode::Range`.
 */
ModuleImportNode moduleImport(string path) { result.getPath() = path }

/**
 * Gets a (default) import of the given dependency `dep`, such as
 * `require("lodash")` in a context where a package.json file includes
 * `"lodash"` as a dependency.
 */
ModuleImportNode dependencyModuleImport(Dependency dep) {
  result = dep.getAUse("import").(Import).getImportedModuleNode()
}

/**
 * Gets a data flow node that either imports `m` from the module with
 * the given `path`, or accesses `m` as a member on a default or
 * namespace import from `path`.
 */
DataFlow::SourceNode moduleMember(string path, string m) {
  result = moduleImport(path).getAPropertyRead(m)
}

/**
 * The string `method`, `getter`, or `setter`, representing the kind of a function member
 * in a class.
 *
 * Can can be used with `ClassNode.getInstanceMember` to obtain members of a specific kind.
 */
class MemberKind extends string {
  MemberKind() { this = "method" or this = "getter" or this = "setter" }
}

module MemberKind {
  /** The kind of a method, such as `m() {}` */
  MemberKind method() { result = "method" }

  /** The kind of a getter accessor, such as `get f() {}`. */
  MemberKind getter() { result = "getter" }

  /** The kind of a setter accessor, such as `set f() {}`. */
  MemberKind setter() { result = "setter" }

  /** The `getter` and `setter` kinds. */
  MemberKind accessor() { result = getter() or result = setter() }

  /**
   * Gets the member kind of a given syntactic member declaration in a class.
   */
  MemberKind of(MemberDeclaration decl) {
    decl instanceof GetterMethodDeclaration and result = getter()
    or
    decl instanceof SetterMethodDeclaration and result = setter()
    or
    decl instanceof MethodDeclaration and
    not decl instanceof AccessorMethodDeclaration and
    not decl instanceof ConstructorDeclaration and
    result = method()
  }
}

/**
 * A data flow node corresponding to a class definition or a function definition
 * acting as a class.
 *
 * The following patterns are recognized as classes and methods:
 * ```
 * class C {
 *   method()
 * }
 *
 * function F() {}
 *
 * F.prototype.method = function() {}
 *
 * F.prototype = {
 *   method: function() {}
 * }
 *
 * extend(F.prototype, {
 *   method: function() {}
 * });
 * ```
 *
 * Additional patterns can be recognized as class nodes, by extending `DataFlow::ClassNode::Range`.
 */
class ClassNode extends DataFlow::SourceNode {
  ClassNode::Range impl;

  ClassNode() { this = impl }

  /**
   * Gets the unqualified name of the class, if it has one or one can be determined from the context.
   */
  string getName() { result = impl.getName() }

  /**
   * Gets a description of the class.
   */
  string describe() { result = impl.describe() }

  /**
   * Gets the constructor function of this class.
   */
  FunctionNode getConstructor() { result = impl.getConstructor() }

  /**
   * Gets an instance method declared in this class, with the given name, if any.
   *
   * Does not include methods from superclasses.
   */
  FunctionNode getInstanceMethod(string name) {
    result = impl.getInstanceMember(name, MemberKind::method())
  }

  /**
   * Gets an instance method declared in this class.
   *
   * The constructor is not considered an instance method.
   *
   * Does not include methods from superclasses.
   */
  FunctionNode getAnInstanceMethod() { result = impl.getAnInstanceMember(MemberKind::method()) }

  /**
   * Gets the instance method, getter, or setter with the given name and kind.
   *
   * Does not include members from superclasses.
   */
  FunctionNode getInstanceMember(string name, MemberKind kind) {
    result = impl.getInstanceMember(name, kind)
  }

  /**
   * Gets an instance method, getter, or setter with the given kind.
   *
   * Does not include members from superclasses.
   */
  FunctionNode getAnInstanceMember(MemberKind kind) { result = impl.getAnInstanceMember(kind) }

  /**
   * Gets an instance method, getter, or setter declared in this class.
   *
   * Does not include members from superclasses.
   */
  FunctionNode getAnInstanceMember() { result = impl.getAnInstanceMember(_) }

  /**
   * Gets the static method declared in this class with the given name.
   */
  FunctionNode getStaticMethod(string name) { result = impl.getStaticMethod(name) }

  /**
   * Gets a static method declared in this class.
   *
   * The constructor is not considered a static method.
   */
  FunctionNode getAStaticMethod() { result = impl.getAStaticMethod() }

  /**
   * Gets a dataflow node that refers to the superclass of this class.
   */
  DataFlow::Node getASuperClassNode() { result = impl.getASuperClassNode() }

  /**
   * Gets a direct super class of this class.
   *
   * This predicate can be overridden to customize the class hierarchy.
   */
  ClassNode getADirectSuperClass() { result.getAClassReference().flowsTo(getASuperClassNode()) }

  /**
   * Gets a direct subclass of this class.
   */
  final ClassNode getADirectSubClass() { this = result.getADirectSuperClass() }

  /**
   * Gets the receiver of an instance member or constructor of this class.
   */
  DataFlow::SourceNode getAReceiverNode() {
    result = getConstructor().getReceiver()
    or
    result = getAnInstanceMember().getReceiver()
  }

  /**
   * Gets the abstract value representing the class itself.
   */
  AbstractValue getAbstractClassValue() { result = this.(AnalyzedNode).getAValue() }

  /**
   * Gets the abstract value representing an instance of this class.
   */
  AbstractValue getAbstractInstanceValue() { result = AbstractInstance::of(getAstNode()) }

  /**
   * Gets a dataflow node that refers to this class object.
   *
   * This predicate can be overridden to customize the tracking of class objects.
   */
  DataFlow::SourceNode getAClassReference(DataFlow::TypeTracker t) {
    t.start() and
    result.(AnalyzedNode).getAValue() = getAbstractClassValue()
    or
    exists(DataFlow::TypeTracker t2 | result = getAClassReference(t2).track(t2, t))
  }

  /**
   * Gets a dataflow node that refers to this class object.
   */
  cached
  final DataFlow::SourceNode getAClassReference() {
    result = getAClassReference(DataFlow::TypeTracker::end())
  }

  /**
   * Gets a dataflow node that refers to an instance of this class.
   *
   * This predicate can be overridden to customize the tracking of class instances.
   */
  DataFlow::SourceNode getAnInstanceReference(DataFlow::TypeTracker t) {
    result = getAClassReference(t.continue()).getAnInstantiation()
    or
    t.start() and
    result.(AnalyzedNode).getAValue() = getAbstractInstanceValue() and
    not result = any(DataFlow::ClassNode cls).getAReceiverNode()
    or
    t.start() and
    result = getAReceiverNode()
    or
    // Use a parameter type as starting point of type tracking.
    // Use `t.call()` to emulate the value being passed in through an unseen
    // call site, but not out of the call again.
    t.call() and
    exists(Parameter param |
      this = param.getTypeAnnotation().getClass() and
      result = DataFlow::parameterNode(param)
    )
    or
    result = getAnInstanceReferenceAux(t) and
    // Avoid tracking into the receiver of other classes.
    // Note that this also blocks flows into a property of the receiver,
    // but the `localFieldStep` rule will often compensate for this.
    not result = any(DataFlow::ClassNode cls).getAReceiverNode()
  }

  pragma[noinline]
  private DataFlow::SourceNode getAnInstanceReferenceAux(DataFlow::TypeTracker t) {
    exists(DataFlow::TypeTracker t2 | result = getAnInstanceReference(t2).track(t2, t))
  }

  /**
   * Gets a dataflow node that refers to an instance of this class.
   */
  cached
  final DataFlow::SourceNode getAnInstanceReference() {
    result = getAnInstanceReference(DataFlow::TypeTracker::end())
  }

  /**
   * Gets a property read that accesses the property `name` on an instance of this class.
   *
   * Concretely, this holds when the base is an instance of this class or a subclass thereof.
   *
   * This predicate may be overridden to customize the class hierarchy analysis.
   */
  DataFlow::PropRead getAnInstanceMemberAccess(string name) {
    result = getAnInstanceReference().getAPropertyRead(name)
    or
    exists(DataFlow::ClassNode subclass |
      result = subclass.getAnInstanceMemberAccess(name) and
      not exists(subclass.getAnInstanceMember(name)) and
      subclass = getADirectSubClass()
    )
  }

  /**
   * Gets an access to a static member of this class.
   */
  DataFlow::PropRead getAStaticMemberAccess(string name) {
    result = getAClassReference().getAPropertyRead(name)
  }

  /**
   * Holds if this class is exposed in the global scope through the given qualified name.
   */
  pragma[noinline]
  predicate hasQualifiedName(string name) {
    exists(DataFlow::Node rhs |
      getAClassReference().flowsTo(rhs) and
      name = GlobalAccessPath::fromRhs(rhs) and
      GlobalAccessPath::isAssignedInUniqueFile(name)
    )
  }
}

module ClassNode {
  /**
   * A dataflow node that should be considered a class node.
   *
   * Subclass this to introduce new kinds of class nodes. If you want to refine
   * the definition of existing class nodes, subclass `DataFlow::ClassNode` instead.
   */
  abstract class Range extends DataFlow::SourceNode {
    /**
     * Gets the name of the class, if it has one.
     */
    abstract string getName();

    /**
     * Gets a description of the class.
     */
    abstract string describe();

    /**
     * Gets the constructor function of this class.
     */
    abstract FunctionNode getConstructor();

    /**
     * Gets the instance member with the given name and kind.
     */
    abstract FunctionNode getInstanceMember(string name, MemberKind kind);

    /**
     * Gets an instance member with the given kind.
     */
    abstract FunctionNode getAnInstanceMember(MemberKind kind);

    /**
     * Gets the static method of this class with the given name.
     */
    abstract FunctionNode getStaticMethod(string name);

    /**
     * Gets a static method of this class.
     *
     * The constructor is not considered a static method.
     */
    abstract FunctionNode getAStaticMethod();

    /**
     * Gets a dataflow node representing a class to be used as the super-class
     * of this node.
     */
    abstract DataFlow::Node getASuperClassNode();
  }

  /**
   * An ES6 class as a `ClassNode` instance.
   */
  private class ES6Class extends Range, DataFlow::ValueNode {
    override ClassDefinition astNode;

    override string getName() { result = astNode.getName() }

    override string describe() { result = astNode.describe() }

    override FunctionNode getConstructor() { result = astNode.getConstructor().getBody().flow() }

    override FunctionNode getInstanceMember(string name, MemberKind kind) {
      exists(MethodDeclaration method |
        method = astNode.getMethod(name) and
        not method.isStatic() and
        kind = MemberKind::of(method) and
        result = method.getBody().flow()
      )
    }

    override FunctionNode getAnInstanceMember(MemberKind kind) {
      exists(MethodDeclaration method |
        method = astNode.getAMethod() and
        not method.isStatic() and
        kind = MemberKind::of(method) and
        result = method.getBody().flow()
      )
    }

    override FunctionNode getStaticMethod(string name) {
      exists(MethodDeclaration method |
        method = astNode.getMethod(name) and
        method.isStatic() and
        result = method.getBody().flow()
      )
      or
      result = getAPropertySource(name)
    }

    override FunctionNode getAStaticMethod() {
      exists(MethodDeclaration method |
        method = astNode.getAMethod() and
        method.isStatic() and
        result = method.getBody().flow()
      )
    }

    override DataFlow::Node getASuperClassNode() { result = astNode.getSuperClass().flow() }
  }

  private DataFlow::PropRef getAPrototypeReferenceInFile(string name, File f) {
    GlobalAccessPath::getAccessPath(result.getBase()) = name and
    result.getPropertyName() = "prototype" and
    result.getFile() = f
  }

  /**
   * A function definition with prototype manipulation as a `ClassNode` instance.
   */
  class FunctionStyleClass extends Range, DataFlow::ValueNode {
    override Function astNode;
    AbstractFunction function;

    FunctionStyleClass() {
      function.getFunction() = astNode and
      (
        exists(DataFlow::PropRef read |
          read.getPropertyName() = "prototype" and
          read.getBase().analyze().getAValue() = function
        )
        or
        exists(string name |
          name = GlobalAccessPath::fromRhs(this) and
          exists(getAPrototypeReferenceInFile(name, getFile()))
        )
      )
    }

    override string getName() { result = astNode.getName() }

    override string describe() { result = astNode.describe() }

    override FunctionNode getConstructor() { result = this }

    private PropertyAccessor getAnAccessor(MemberKind kind) {
      result.getObjectExpr() = getAPrototypeReference().asExpr() and
      (
        kind = MemberKind::getter() and
        result instanceof PropertyGetter
        or
        kind = MemberKind::setter() and
        result instanceof PropertySetter
      )
    }

    override FunctionNode getInstanceMember(string name, MemberKind kind) {
      kind = MemberKind::method() and
      result = getAPrototypeReference().getAPropertySource(name)
      or
      kind = MemberKind::method() and
      result = getConstructor().getReceiver().getAPropertySource(name)
      or
      exists(PropertyAccessor accessor |
        accessor = getAnAccessor(kind) and
        accessor.getName() = name and
        result = accessor.getInit().flow()
      )
    }

    override FunctionNode getAnInstanceMember(MemberKind kind) {
      kind = MemberKind::method() and
      result = getAPrototypeReference().getAPropertySource()
      or
      kind = MemberKind::method() and
      result = getConstructor().getReceiver().getAPropertySource()
      or
      exists(PropertyAccessor accessor |
        accessor = getAnAccessor(kind) and
        result = accessor.getInit().flow()
      )
    }

    override FunctionNode getStaticMethod(string name) { result = getAPropertySource(name) }

    override FunctionNode getAStaticMethod() { result = getAPropertySource() }

    /**
     * Gets a reference to the prototype of this class.
     */
    DataFlow::SourceNode getAPrototypeReference() {
      exists(DataFlow::SourceNode base | base.analyze().getAValue() = function |
        result = base.getAPropertyRead("prototype")
        or
        result = base.getAPropertySource("prototype")
      )
      or
      exists(string name |
        GlobalAccessPath::fromRhs(this) = name and
        result = getAPrototypeReferenceInFile(name, getFile())
      )
      or
      exists(ExtendCall call |
        call.getDestinationOperand() = getAPrototypeReference() and
        result = call.getASourceOperand()
      )
    }

    override DataFlow::Node getASuperClassNode() {
      // C.prototype = Object.create(D.prototype)
      exists(DataFlow::InvokeNode objectCreate, DataFlow::PropRead superProto |
        getAPropertySource("prototype") = objectCreate and
        objectCreate = DataFlow::globalVarRef("Object").getAMemberCall("create") and
        superProto.flowsTo(objectCreate.getArgument(0)) and
        superProto.getPropertyName() = "prototype" and
        result = superProto.getBase()
      )
      or
      // C.prototype = new D()
      exists(DataFlow::NewNode newCall |
        getAPropertySource("prototype") = newCall and
        result = newCall.getCalleeNode()
      )
    }
  }
}

/**
 * An invocation that is modeled as a partial function application.
 *
 * This contributes additional argument-passing flow edges that should be added to all data flow configurations.
 */
abstract class AdditionalPartialInvokeNode extends DataFlow::InvokeNode {
  /**
   * Holds if `argument` is passed as argument `index` to the function in `callback`.
   */
  abstract predicate isPartialArgument(DataFlow::Node callback, DataFlow::Node argument, int index);

  /** Gets the data flow node referring to the bound function, if such a node exists. */
  DataFlow::SourceNode getBoundFunction(int boundArgs) { none() }
}

/**
 * A partial call through the built-in `Function.prototype.bind`.
 */
private class BindPartialCall extends AdditionalPartialInvokeNode, DataFlow::MethodCallNode {
  BindPartialCall() { getMethodName() = "bind" }

  override predicate isPartialArgument(DataFlow::Node callback, DataFlow::Node argument, int index) {
    index >= 0 and
    callback = getReceiver() and
    argument = getArgument(index + 1)
  }

  override DataFlow::SourceNode getBoundFunction(int boundArgs) {
    boundArgs = getNumArgument() - 1 and
    result = this
  }
}

/**
 * A partial call through `_.partial`.
 */
private class LodashPartialCall extends AdditionalPartialInvokeNode {
  LodashPartialCall() { this = LodashUnderscore::member("partial").getACall() }

  override predicate isPartialArgument(DataFlow::Node callback, DataFlow::Node argument, int index) {
    index >= 0 and
    callback = getArgument(0) and
    argument = getArgument(index + 1)
  }

  override DataFlow::SourceNode getBoundFunction(int boundArgs) {
    boundArgs = getNumArgument() - 1 and
    result = this
  }
}

/**
 * A partial call through `ramda.partial`.
 */
private class RamdaPartialCall extends AdditionalPartialInvokeNode {
  RamdaPartialCall() { this = DataFlow::moduleMember("ramda", "partial").getACall() }

  private DataFlow::ArrayCreationNode getArgumentsArray() {
    result.flowsTo(getArgument(1))
  }

  override predicate isPartialArgument(DataFlow::Node callback, DataFlow::Node argument, int index) {
    callback = getArgument(0) and
    argument = getArgumentsArray().getElement(index)
  }

  override DataFlow::SourceNode getBoundFunction(int boundArgs) {
    boundArgs = getArgumentsArray().getSize() and
    result = this
  }
}
