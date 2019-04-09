import python


private import semmle.python.objects.TObject
private import semmle.python.objects.ObjectInternal
private import semmle.python.pointsto.PointsTo
private import semmle.python.pointsto.PointsToContext
private import semmle.python.pointsto.MRO
private import semmle.python.types.Builtins


abstract class ClassObjectInternal extends ObjectInternal {

    override boolean booleanValue() {
        result = true
    }

    override boolean isClass() { result = true }

    override int intValue() {
        none()
    }

    override string strValue() {
        none()
    }

    string getName() {
        result = this.getClassDeclaration().getName()
    }

    boolean isSpecial() {
        result = Types::getMro(this).isSpecial()
    }

    override boolean isDescriptor() { result = false }

    override predicate descriptorGet(ObjectInternal instance, ObjectInternal value, CfgOrigin origin) { none() }

    override predicate binds(ObjectInternal instance, string name, ObjectInternal descriptor) {
        instance = this and
        PointsToInternal::attributeRequired(this, name) and
        this.lookup(name, descriptor, _) and
        descriptor.isDescriptor() = true
    }

    abstract predicate lookup(string name, ObjectInternal value, CfgOrigin origin);

    /** Approximation to descriptor protocol, skipping meta-descriptor protocol */
    override predicate attribute(string name, ObjectInternal value, CfgOrigin origin) {
        exists(ObjectInternal descriptor, CfgOrigin desc_origin |
            this.lookup(name, descriptor, desc_origin) |
            descriptor.isDescriptor() = false and
            value = descriptor and origin = desc_origin
            or
            descriptor.isDescriptor() = true and
            descriptor.descriptorGet(this, value, origin)
        )
    }

}

class PythonClassObjectInternal extends ClassObjectInternal, TPythonClassObject {

    Class getScope() {
        exists(ClassExpr expr |
            this = TPythonClassObject(expr.getAFlowNode()) and
            result = expr.getInnerScope()
        )
    }

    override string toString() {
        result = "class " + this.getScope().getName()
    }

    override predicate introduced(ControlFlowNode node, PointsToContext context) {
        this = TPythonClassObject(node) and context.appliesTo(node)
    }

    override ClassDecl getClassDeclaration() {
        this = TPythonClassObject(result)
    }

    override ObjectInternal getClass() {
        result = Types::getMetaClass(this)
    }

    override Builtin getBuiltin() {
        none()
    }

    override ControlFlowNode getOrigin() {
        this = TPythonClassObject(result)
    }

    override predicate calleeAndOffset(Function scope, int paramOffset) {
        exists(PythonFunctionObjectInternal init |
            // TO DO... Lookup init...
            none() |
            init.getScope() = scope and paramOffset = 1
        )
    }

    override predicate lookup(string name, ObjectInternal value, CfgOrigin origin) {
        exists(ClassObjectInternal decl |
            decl = Types::getMro(this).findDeclaringClass(name) |
            Types::declaredAttribute(decl, name, value, origin)
        )
    }

    override predicate attributesUnknown() { none() }

    override predicate callResult(PointsToContext callee, ObjectInternal obj, CfgOrigin origin) {
        none()
    }

    override predicate callResult(ObjectInternal obj, CfgOrigin origin) {
        // Handled by Instance classes.
        none()
    }

    override boolean isComparable() { result = true }

}

class BuiltinClassObjectInternal extends ClassObjectInternal, TBuiltinClassObject {

    override Builtin getBuiltin() {
        this = TBuiltinClassObject(result)
    }

    override string toString() {
        result = "builtin-class " + this.getBuiltin().getName()
    }

    override predicate introduced(ControlFlowNode node, PointsToContext context) {
        none()
    }

    override ClassDecl getClassDeclaration() {
        this = TBuiltinClassObject(result)
    }

    override ObjectInternal getClass() {
        result = TBuiltinClassObject(this.getBuiltin().getClass())
        or
        this.getBuiltin().getClass() = Builtin::special("type") and
        result = TType()
    }

    override ControlFlowNode getOrigin() {
        none()
    }

    override predicate calleeAndOffset(Function scope, int paramOffset) {
        none()
    }

    override predicate lookup(string name, ObjectInternal value, CfgOrigin origin) {
        value = ObjectInternal::fromBuiltin(this.getBuiltin().getMember(name)) and
        origin = CfgOrigin::unknown()
    }

    override predicate attributesUnknown() { none() }

    override predicate callResult(PointsToContext callee, ObjectInternal obj, CfgOrigin origin) {
        none()
    }

    override predicate callResult(ObjectInternal obj, CfgOrigin origin) {
        // Handled by Instance classes.
        none()
    }

    override boolean isComparable() { result = true }

}


class UnknownClassInternal extends ClassObjectInternal, TUnknownClass {

    override string toString() {
        result = "Unknown class"
    }

    override ClassDecl getClassDeclaration() {
        result = Builtin::unknownType()
    }

    override ObjectInternal getClass() {
        result = this
    }

    override predicate introduced(ControlFlowNode node, PointsToContext context) {
        none()
    }

    override boolean isComparable() { result = false }

    override Builtin getBuiltin() {
        none()
    }

    override predicate callResult(PointsToContext callee, ObjectInternal obj, CfgOrigin origin) {
        none()
    }

    override predicate callResult(ObjectInternal obj, CfgOrigin origin) {
        obj = ObjectInternal::unknown() and origin = CfgOrigin::unknown()
    }

    override ControlFlowNode getOrigin() {
        none()
    }

    override predicate calleeAndOffset(Function scope, int paramOffset) {
        none()
    }

    override predicate lookup(string name, ObjectInternal value, CfgOrigin origin) {
        none()
    }

    override predicate attributesUnknown() { any() }

}

class TypeInternal extends ClassObjectInternal, TType {

    override string toString() {
        result = "builtin-class type"
    }

    override ClassDecl getClassDeclaration() {
        result = Builtin::special("type")
    }

    override ObjectInternal getClass() {
        result = this
    }

    override predicate introduced(ControlFlowNode node, PointsToContext context) {
        none()
    }

    override boolean isComparable() { result = true }

    override Builtin getBuiltin() {
        result = Builtin::special("type")
    }

    override predicate callResult(PointsToContext callee, ObjectInternal obj, CfgOrigin origin) {
        none()
    }

    override predicate callResult(ObjectInternal obj, CfgOrigin origin) {
        none()
    }

    override ControlFlowNode getOrigin() {
        none()
    }

    override predicate calleeAndOffset(Function scope, int paramOffset) {
        none()
    }

    override predicate lookup(string name, ObjectInternal value, CfgOrigin origin) {
        none()
    }

    override predicate attributesUnknown() { any() }

}
