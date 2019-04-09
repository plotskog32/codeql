
import python

private import semmle.python.objects.TObject
private import semmle.python.objects.ObjectInternal
private import semmle.python.pointsto.PointsTo
private import semmle.python.pointsto.PointsToContext
private import semmle.python.pointsto.MRO
private import semmle.python.types.Builtins


abstract class CallableObjectInternal extends ObjectInternal {

    override int intValue() {
        none()
    }

    override string strValue() {
        none()
    }

    override boolean isClass() { result = false }

    /** The boolean value of this object, if it has one */
    override boolean booleanValue() {
        result = true
    }

    override ClassDecl getClassDeclaration() {
        none()
    }

    abstract string getName();

    override predicate attribute(string name, ObjectInternal value, CfgOrigin origin) {
        none()
    }

    override predicate attributesUnknown() { none() }

    abstract Function getScope();

    override predicate binds(ObjectInternal instance, string name, ObjectInternal descriptor) { none() }

    abstract CallNode getACall(PointsToContext ctx);

    CallNode getACall() { result = this.getACall(_) }

    abstract NameNode getParameter(int n);

    abstract NameNode getParameterByName(string name);

}


class PythonFunctionObjectInternal extends CallableObjectInternal, TPythonFunctionObject {

    override Function getScope() {
        exists(CallableExpr expr |
            this = TPythonFunctionObject(expr.getAFlowNode()) and
            result = expr.getInnerScope()
        )
    }

    override string toString() {
        result = "Function " + this.getScope().getQualifiedName()
    }

    override predicate introduced(ControlFlowNode node, PointsToContext context) {
        this = TPythonFunctionObject(node) and context.appliesTo(node)
    }

    override ObjectInternal getClass() {
        result = TBuiltinClassObject(Builtin::special("FunctionType"))
    }

    override boolean isComparable() { result = true }

    override Builtin getBuiltin() {
        none()
    }

    override ControlFlowNode getOrigin() {
        this = TPythonFunctionObject(result)
    }

    pragma [nomagic]
    override predicate callResult(PointsToContext callee, ObjectInternal obj, CfgOrigin origin) {
        exists(Function func, ControlFlowNode rval, ControlFlowNode forigin |
            func = this.getScope() and
            callee.appliesToScope(func) |
            rval = func.getAReturnValueFlowNode() and
            PointsToInternal::pointsTo(rval, callee, obj, forigin) and
            origin = CfgOrigin::fromCfgNode(forigin)
        )
        or
        procedureReturnsNone(callee, obj, origin)
    }

    private predicate procedureReturnsNone(PointsToContext callee, ObjectInternal obj, CfgOrigin origin) {
        exists(Function func |
            func = this.getScope() and
            callee.appliesToScope(func) |
            PointsToInternal::reachableBlock(blockReturningNone(func), callee) and
            obj = ObjectInternal::none_() and
            origin = CfgOrigin::unknown()
        )
    }

    pragma [noinline]
    override predicate callResult(ObjectInternal obj, CfgOrigin origin) { 
        this.getScope().isProcedure() and
        obj = ObjectInternal::none_() and
        origin = CfgOrigin::fromCfgNode(this.getScope().getEntryNode())
    }

    override predicate calleeAndOffset(Function scope, int paramOffset) {
        scope = this.getScope() and paramOffset = 0
    }

    override string getName() {
        result = this.getScope().getName()
    }

    override boolean isDescriptor() { result = true }

    override predicate descriptorGet(ObjectInternal instance, ObjectInternal value, CfgOrigin origin) {
        value = TBoundMethod(instance, this) and origin = CfgOrigin::unknown()
    }

    override CallNode getACall(PointsToContext ctx) {
        PointsTo::pointsTo(result.getFunction(), ctx, this, _)
        or
        exists(BoundMethodObjectInternal bm |
            bm.getACall(ctx) = result and this = bm.getFunction()
        )
    }

    override NameNode getParameter(int n) {
        result.getNode() = this.getScope().getArg(n)
    }

    override NameNode getParameterByName(string name) {
        result.getNode() = this.getScope().getArgByName(name)
    }

}


private BasicBlock blockReturningNone(Function func) {
    exists(Return ret |
        not exists(ret.getValue()) and
        ret.getScope() = func and
        result = ret.getAFlowNode().getBasicBlock()
    )
}


class BuiltinFunctionObjectInternal extends CallableObjectInternal, TBuiltinFunctionObject {

    override Builtin getBuiltin() {
        this = TBuiltinFunctionObject(result)
    }

    override string toString() {
        result = "Builtin-function " + this.getBuiltin().getName()
    }

    override predicate introduced(ControlFlowNode node, PointsToContext context) {
        none()
    }

    override ObjectInternal getClass() {
        result = TBuiltinClassObject(this.getBuiltin().getClass())
    }

    override boolean isComparable() { result = true }

    override predicate callResult(PointsToContext callee, ObjectInternal obj, CfgOrigin origin) { none() }

    pragma [noinline]
    override predicate callResult(ObjectInternal obj, CfgOrigin origin) {
        exists(Builtin func, BuiltinClassObjectInternal cls |
            func = this.getBuiltin() and
            func != Builtin::builtin("isinstance") and
            func != Builtin::builtin("issubclass") and
            func != Builtin::builtin("callable") and
            cls = ObjectInternal::fromBuiltin(this.getReturnType()) |
            obj = TUnknownInstance(cls)
            or
            cls = ObjectInternal::noneType() and obj = ObjectInternal::none_()
            or
            cls = ObjectInternal::builtin("bool") and obj = ObjectInternal::bool(_)
        ) and
        origin = CfgOrigin::unknown()
    }

    override ControlFlowNode getOrigin() {
        none()
    }

    override predicate calleeAndOffset(Function scope, int paramOffset) {
        none()
    }

    override string getName() {
        result = this.getBuiltin().getName()
    }

    Builtin getReturnType() {
        exists(Builtin func |
            func = this.getBuiltin() |
            /* Enumerate the types of a few builtin functions, that the CPython analysis misses.
            */
            func = Builtin::builtin("hex") and result = Builtin::special("str")
            or
            func = Builtin::builtin("oct") and result = Builtin::special("str")
            or
            func = Builtin::builtin("intern") and result = Builtin::special("str")
            or
            /* Fix a few minor inaccuracies in the CPython analysis */ 
            ext_rettype(func, result) and not (
                func = Builtin::builtin("__import__") and result = Builtin::special("NoneType")
                or
                func = Builtin::builtin("compile") and result = Builtin::special("NoneType")
                or
                func = Builtin::builtin("sum")
                or
                func = Builtin::builtin("filter")
            )
        )
    }

    override Function getScope() { none() }

    override boolean isDescriptor() { result = false }

    override predicate descriptorGet(ObjectInternal instance, ObjectInternal value, CfgOrigin origin) { none() }

    override CallNode getACall(PointsToContext ctx) {
        PointsTo::pointsTo(result.getFunction(), ctx, this, _)
    }

    override NameNode getParameter(int n) {
        none()
    }

    override NameNode getParameterByName(string name) {
        none()
    }

}


class BuiltinMethodObjectInternal extends CallableObjectInternal, TBuiltinMethodObject {

    override Builtin getBuiltin() {
        this = TBuiltinMethodObject(result)
    }

    override string toString() {
        result = "builtin method " + this.getBuiltin().getName()
    }

    override ObjectInternal getClass() {
        result = TBuiltinClassObject(this.getBuiltin().getClass())
    }

    override predicate introduced(ControlFlowNode node, PointsToContext context) {
        none()
    }

    override boolean isComparable() { result = true }

    override predicate callResult(PointsToContext callee, ObjectInternal obj, CfgOrigin origin) { none() }

    pragma [noinline]
    override predicate callResult(ObjectInternal obj, CfgOrigin origin) {
        exists(Builtin func, BuiltinClassObjectInternal cls |
            func = this.getBuiltin() and
            cls = ObjectInternal::fromBuiltin(this.getReturnType()) |
            obj = TUnknownInstance(cls)
            or
            cls = ObjectInternal::noneType() and obj = ObjectInternal::none_()
            or
            cls = ObjectInternal::builtin("bool") and obj = ObjectInternal::bool(_)
        ) and
        origin = CfgOrigin::unknown()
    }

    Builtin getReturnType() {
        exists(Builtin func |
            func = this.getBuiltin() |
            ext_rettype(func, result)
        )
    }

    override ControlFlowNode getOrigin() {
        none()
    }

    override predicate calleeAndOffset(Function scope, int paramOffset) {
        none()
    }

    override string getName() {
        result = this.getBuiltin().getName()
    }

    override Function getScope() { none() }

    override boolean isDescriptor() { result = true }

    override predicate descriptorGet(ObjectInternal instance, ObjectInternal value, CfgOrigin origin) {
        instance.isClass() = false and
        value = TBoundMethod(instance, this) and origin = CfgOrigin::unknown()
        or
        any(ObjectInternal obj).binds(instance, _, this) and
        instance.isClass() = true and 
        value = this and origin = CfgOrigin::unknown()
    }

    override CallNode getACall(PointsToContext ctx) {
        PointsTo::pointsTo(result.getFunction(), ctx, this, _)
    }

    override NameNode getParameter(int n) {
        none()
    }

    override NameNode getParameterByName(string name) {
        none()
    }

}

class BoundMethodObjectInternal extends CallableObjectInternal, TBoundMethod {

    override Builtin getBuiltin() {
        none()
    }

    CallableObjectInternal getFunction() {
        this = TBoundMethod(_, result)
    }

    ObjectInternal getSelf() {
        this = TBoundMethod(result, _)
    }

    override string toString() {
        result = "Method(" + this.getFunction() + ", " + this.getSelf() + ")"
    }

    override ObjectInternal getClass() {
        result = TBuiltinClassObject(Builtin::special("MethodType"))
    }

    override predicate introduced(ControlFlowNode node, PointsToContext context) {
        none()
    }

    override boolean isComparable() { result = false }

    override predicate callResult(PointsToContext callee, ObjectInternal obj, CfgOrigin origin) {
        this.getFunction().callResult(callee, obj, origin)
    }

    override predicate callResult(ObjectInternal obj, CfgOrigin origin) {
        this.getFunction().callResult(obj, origin)
    }

    override ControlFlowNode getOrigin() {
        none()
    }

    override predicate calleeAndOffset(Function scope, int paramOffset) {
        this.getFunction().calleeAndOffset(scope, paramOffset-1)
    }

    override string getName() {
        result = this.getFunction().getName()
    }


    override Function getScope() { 
        result = this.getFunction().getScope()
    }

    override boolean isDescriptor() { result = false }

    override predicate descriptorGet(ObjectInternal instance, ObjectInternal value, CfgOrigin origin) { none() }

    override CallNode getACall(PointsToContext ctx) {
        PointsTo::pointsTo(result.getFunction(), ctx, this, _)
    }

    override NameNode getParameter(int n) {
        result = this.getFunction().getParameter(n+1)
    }

    override NameNode getParameterByName(string name) {
        result = this.getFunction().getParameterByName(name)
    }

}

class ClassMethodObjectInternal extends ObjectInternal, TClassMethod {

    override string toString() {
        result = "classmethod(" + this.getFunction() + ")"
    }

    override boolean booleanValue() { result = true }

    override predicate introduced(ControlFlowNode node, PointsToContext context) {
        exists(CallableObjectInternal function |
            this = TClassMethod(node, function) and
            class_method(node, function, context)
        )
    }

    CallableObjectInternal getFunction() {
        this = TClassMethod(_, result)
    }

    override ClassDecl getClassDeclaration() { none() }

    override boolean isClass() { result = false }

    override ObjectInternal getClass() { result = ObjectInternal::classMethod() }

    override boolean isComparable() { none() }

    override Builtin getBuiltin() { none() }

    override ControlFlowNode getOrigin() { this = TClassMethod(result, _) }

    override predicate callResult(PointsToContext callee, ObjectInternal obj, CfgOrigin origin) { none() }

    override predicate callResult(ObjectInternal obj, CfgOrigin origin) { none() }

    override int intValue() { none() }

    override string strValue() { none() }

    override predicate calleeAndOffset(Function scope, int paramOffset) { none() }

    override predicate attribute(string name, ObjectInternal value, CfgOrigin origin) { none() }

    override predicate attributesUnknown() { none() }

    override boolean isDescriptor() { result = true }

    override predicate descriptorGet(ObjectInternal instance, ObjectInternal value, CfgOrigin origin) {
        any(ObjectInternal obj).binds(instance, _, this) and
        exists(ObjectInternal cls |
            instance.isClass() = false and cls = instance.getClass()
            or
            instance.isClass() = true and cls = instance
            |
            value = TBoundMethod(cls, this.getFunction()) and
            origin = CfgOrigin::unknown()
        )
    }

    override predicate binds(ObjectInternal cls, string name, ObjectInternal descriptor) {
        descriptor = this.getFunction() and
        exists(ObjectInternal instance |
            any(ObjectInternal obj).binds(instance, name, this) |
            instance.isClass() = false and cls = instance.getClass()
            or
            instance.isClass() = true and cls = instance
        )
    }

}

class StaticMethodObjectInternal extends ObjectInternal, TStaticMethod {

    override string toString() {
        result = "staticmethod()"
    }

    override boolean booleanValue() { result = true }

    override predicate introduced(ControlFlowNode node, PointsToContext context) {
        exists(CallableObjectInternal function |
            this = TStaticMethod(node, function) and
            static_method(node, function, context)
        )
    }

    CallableObjectInternal getFunction() {
        this = TStaticMethod(_, result)
    }

    override ClassDecl getClassDeclaration() { none() }

    override boolean isClass() { result = false }

    override ObjectInternal getClass() { result = ObjectInternal::builtin("staticmethod") }

    override boolean isComparable() { none() }

    override Builtin getBuiltin() { none() }

    override ControlFlowNode getOrigin() { this = TStaticMethod(result, _) }

    override predicate callResult(PointsToContext callee, ObjectInternal obj, CfgOrigin origin) { none() }

    override predicate callResult(ObjectInternal obj, CfgOrigin origin) { none() }

    override int intValue() { none() }

    override string strValue() { none() }

    override predicate calleeAndOffset(Function scope, int paramOffset) {
        this.getFunction().calleeAndOffset(scope, paramOffset)
    }

    override predicate attribute(string name, ObjectInternal value, CfgOrigin origin) { none() }

    override predicate attributesUnknown() { none() }

    override boolean isDescriptor() { result = true }

    override predicate descriptorGet(ObjectInternal instance, ObjectInternal value, CfgOrigin origin) {
        any(ObjectInternal obj).binds(instance, _, this) and
        value = this.getFunction() and origin = CfgOrigin::unknown()
    }

    override predicate binds(ObjectInternal instance, string name, ObjectInternal descriptor) { none() }

}



