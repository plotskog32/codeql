import python


private import semmle.python.objects.TObject
private import semmle.python.objects.ObjectInternal
private import semmle.python.pointsto.PointsTo
private import semmle.python.pointsto.MRO
private import semmle.python.pointsto.PointsToContext
private import semmle.python.types.Builtins

class SpecificInstanceInternal extends TSpecificInstance, ObjectInternal {

    override string toString() {
        result = this.getOrigin().getNode().toString()
    }

    /** The boolean value of this object, if it has one */
    override boolean booleanValue() {
        //result = this.getClass().instancesBooleanValue()
        result = maybe()
    }

    override predicate introduced(ControlFlowNode node, PointsToContext context) {
        this = TSpecificInstance(node, _, context)
    }

    /** Gets the class declaration for this object, if it is a declared class. */
    override ClassDecl getClassDeclaration() {
        none()
    }

    override boolean isClass() { result = false }

    override boolean isComparable() { result = true }

    override ObjectInternal getClass() {
        this = TSpecificInstance(_, result, _)
    }

    /** Gets the `Builtin` for this object, if any.
     * All objects (except unknown and undefined values) should return 
     * exactly one result for either this method or `getOrigin()`.
     */
    override Builtin getBuiltin() {
        none()
    }

    /** Gets a control flow node that represents the source origin of this 
     * objects.
     * All objects (except unknown and undefined values) should return 
     * exactly one result for either this method or `getBuiltin()`.
     */
    override ControlFlowNode getOrigin() {
        this = TSpecificInstance(result, _, _)
    }

    override predicate callResult(PointsToContext callee, ObjectInternal obj, CfgOrigin origin) {
        none()
    }

     override predicate callResult(ObjectInternal obj, CfgOrigin origin) {
        // In general instances aren't callable, but some are...
        // TO DO -- Handle cases where class overrides __call__
        none()
    }

     override int intValue() {
        none()
    }

    override string strValue() {
        none()
    }

    override predicate calleeAndOffset(Function scope, int paramOffset) {
        none()
    }

    pragma [nomagic]
    override predicate attribute(string name, ObjectInternal value, CfgOrigin origin) {
        PointsToInternal::attributeRequired(this, name) and
        exists(ObjectInternal cls_attr, CfgOrigin attr_orig |
            this.getClass().(ClassObjectInternal).lookup(name, cls_attr, attr_orig)
            |
            cls_attr.isDescriptor() = false and value = cls_attr and origin = attr_orig
            or
            cls_attr.isDescriptor() = true and cls_attr.descriptorGetInstance(this, value, origin)
        )
        or
        exists(EssaVariable self, PythonFunctionObjectInternal init, Context callee |
            BaseFlow::reaches_exit(self) and
            self.getSourceVariable().(Variable).isSelf() and
            self.getScope() = init.getScope() and
            exists(CallNode call, Context caller, ClassObjectInternal cls |
                this = TSpecificInstance(call, cls, caller) and
                callee.fromCall(this.getOrigin(), caller) and
                cls.lookup("__init__", init, _)
            ) and
            AttributePointsTo::variableAttributePointsTo(self, callee, name, value, origin)
        )
    }

    pragma [noinline] override predicate attributesUnknown() { any() }

    override boolean isDescriptor() { result = false }

    pragma [noinline] override predicate descriptorGetClass(ObjectInternal cls, ObjectInternal value, CfgOrigin origin) { none() }

    pragma [noinline] override predicate descriptorGetInstance(ObjectInternal instance, ObjectInternal value, CfgOrigin origin) { none() }

    pragma [noinline] override predicate binds(ObjectInternal instance, string name, ObjectInternal descriptor) {
        exists(ClassObjectInternal cls |
            receiver_type(_, name, this, cls) and
            cls.lookup(name, descriptor, _) and
            descriptor.isDescriptor() = true
        ) and
        this = instance
    }

    override int length() {
        result = lengthFromClass(this.getClass())
    }

}


class SelfInstanceInternal extends TSelfInstance, ObjectInternal {

    override string toString() {
        result = "self instance of " + this.getClass().(ClassObjectInternal).getName()
    }

    /** The boolean value of this object, if it has one */
    override boolean booleanValue() {
        //result = this.getClass().instancesBooleanValue()
        result = maybe()
    }

    override predicate introduced(ControlFlowNode node, PointsToContext context) {
        none()
    }

    predicate parameterAndContext(ParameterDefinition def, PointsToContext context) {
        this = TSelfInstance(def, context, _)
    }

    /** Gets the class declaration for this object, if it is a declared class. */
    override ClassDecl getClassDeclaration() {
        none()
    }

    override boolean isClass() { result = false }

    override boolean isComparable() { result = false }

    override ObjectInternal getClass() {
        this = TSelfInstance(_, _, result)
    }

    override Builtin getBuiltin() {
        none()
    }

    override ControlFlowNode getOrigin() {
        exists(ParameterDefinition def |
            this = TSelfInstance(def, _, _) and
            result = def.getDefiningNode()
        )
    }

    override predicate callResult(PointsToContext callee, ObjectInternal obj, CfgOrigin origin) {
        none()
    }

     override predicate callResult(ObjectInternal obj, CfgOrigin origin) {
        // In general instances aren't callable, but some are...
        // TO DO -- Handle cases where class overrides __call__
        none()
    }

     override int intValue() {
        none()
    }

    override string strValue() {
        none()
    }

    override predicate calleeAndOffset(Function scope, int paramOffset) {
        none()
    }

    pragma [nomagic] override predicate attribute(string name, ObjectInternal value, CfgOrigin origin) {
        PointsToInternal::attributeRequired(this, name) and
        exists(ObjectInternal cls_attr, CfgOrigin attr_orig |
            this.getClass().(ClassObjectInternal).lookup(name, cls_attr, attr_orig)
            |
            cls_attr.isDescriptor() = false and value = cls_attr and origin = attr_orig
            or
            cls_attr.isDescriptor() = true and cls_attr.descriptorGetInstance(this, value, origin)
        )
    }

    pragma [noinline] override predicate attributesUnknown() { any() }

    override boolean isDescriptor() { result = false }

    pragma [noinline] override predicate descriptorGetClass(ObjectInternal cls, ObjectInternal value, CfgOrigin origin) { none() }

    pragma [noinline] override predicate descriptorGetInstance(ObjectInternal instance, ObjectInternal value, CfgOrigin origin) { none() }

    pragma [noinline] override predicate binds(ObjectInternal instance, string name, ObjectInternal descriptor) {
        exists(AttrNode attr, ClassObjectInternal cls |
            receiver_type(attr, name, this, cls) and
            cls_descriptor(cls, name, descriptor)
        ) and
        instance = this
    }

    override int length() {
        result = lengthFromClass(this.getClass())
    }

}

/** Represents a value that has a known class, but no other information */
class UnknownInstanceInternal extends TUnknownInstance, ObjectInternal {

    override string toString() {
        result = "instance of " + this.getClass().(ClassObjectInternal).getName()
    }

    /** The boolean value of this object, if it has one */
    override boolean booleanValue() {
        //result = this.getClass().instancesBooleanValue()
        result = maybe()
    }

    override predicate introduced(ControlFlowNode node, PointsToContext context) {
        none()
    }

    /** Gets the class declaration for this object, if it is a declared class. */
    override ClassDecl getClassDeclaration() {
        none()
    }

    override boolean isClass() { result = false }

    override boolean isComparable() { result = false }

    override ObjectInternal getClass() {
        this = TUnknownInstance(result)
    }

    /** Gets the `Builtin` for this object, if any.
     * All objects (except unknown and undefined values) should return 
     * exactly one result for either this method or `getOrigin()`.
     */
    override Builtin getBuiltin() {
        none()
    }

    /** Gets a control flow node that represents the source origin of this 
     * objects.
     * All objects (except unknown and undefined values) should return 
     * exactly one result for either this method or `getBuiltin()`.
     */
    override ControlFlowNode getOrigin() {
        none()
    }

    override predicate callResult(PointsToContext callee, ObjectInternal obj, CfgOrigin origin) {
        none()
    }

    override predicate callResult(ObjectInternal obj, CfgOrigin origin) {
        // In general instances aren't callable, but some are...
        // TO DO -- Handle cases where class overrides __call__
        none()
    }

    override int intValue() {
        none()
    }

    override string strValue() {
        none()
    }

    override predicate calleeAndOffset(Function scope, int paramOffset) {
        none()
    }

    pragma [noinline] override predicate attribute(string name, ObjectInternal value, CfgOrigin origin) {
        PointsToInternal::attributeRequired(this, name) and
        exists(ObjectInternal cls_attr, CfgOrigin attr_orig |
            this.getClass().(ClassObjectInternal).lookup(name, cls_attr, attr_orig)
            |
            cls_attr.isDescriptor() = false and value = cls_attr and origin = attr_orig
            or
            cls_attr.isDescriptor() = true and cls_attr.descriptorGetInstance(this, value, origin)
        )
    }

    pragma [noinline] override predicate attributesUnknown() { any() }

    override boolean isDescriptor() { result = false }

    pragma [noinline] override predicate descriptorGetClass(ObjectInternal cls, ObjectInternal value, CfgOrigin origin) { none() }

    pragma [noinline] override predicate descriptorGetInstance(ObjectInternal instance, ObjectInternal value, CfgOrigin origin) { none() }

    pragma [noinline] override predicate binds(ObjectInternal instance, string name, ObjectInternal descriptor) {
        exists(AttrNode attr, ClassObjectInternal cls |
            receiver_type(attr, name, this, cls) and
            cls_descriptor(cls, name, descriptor)
        ) and
        instance = this
    }

    override int length() {
        result = lengthFromClass(this.getClass())
    }

}

private int lengthFromClass(ClassObjectInternal cls) {
    Types::getMro(cls).declares("__len__") and result = -1
}

private predicate cls_descriptor(ClassObjectInternal cls, string name, ObjectInternal descriptor) {
    cls.lookup(name, descriptor, _) and
    descriptor.isDescriptor() = true
}

class SuperInstance extends TSuperInstance, ObjectInternal {

    override string toString() {
        result = "super(" + this.getStartClass().toString() + ", " + this.getSelf().toString() + ")"
    }

    override boolean booleanValue() { result = true }

    override predicate introduced(ControlFlowNode node, PointsToContext context) {
        exists(ObjectInternal self, ClassObjectInternal startclass |
            super_instantiation(node, self, startclass, context) and
            this = TSuperInstance(self, startclass)
        )
    }

    ClassObjectInternal getStartClass() {
        this = TSuperInstance(_, result)
    }

    ObjectInternal getSelf() {
        this = TSuperInstance(result, _)
    }

    override ClassDecl getClassDeclaration() { none() }

    override boolean isClass() { result = false }

    override ObjectInternal getClass() {
        result = ObjectInternal::super_()
    }

    override boolean isComparable() { result = false }

    override Builtin getBuiltin() { none() }

    override ControlFlowNode getOrigin() {
        none()
    }

    override predicate callResult(ObjectInternal obj, CfgOrigin origin) { none() }

    override predicate callResult(PointsToContext callee, ObjectInternal obj, CfgOrigin origin) { none() }

    override int intValue() { none() }

    override string strValue() { none() }

    override predicate calleeAndOffset(Function scope, int paramOffset) { none() }

    pragma [noinline] override predicate attributesUnknown() { none() }

    override boolean isDescriptor() { result = false }

    pragma [noinline] override predicate descriptorGetClass(ObjectInternal cls, ObjectInternal value, CfgOrigin origin) { none() }

    pragma [noinline] override predicate descriptorGetInstance(ObjectInternal instance, ObjectInternal value, CfgOrigin origin) { none() }

    pragma [noinline] override predicate attribute(string name, ObjectInternal value, CfgOrigin origin) {
        PointsToInternal::attributeRequired(this, name) and
        exists(ObjectInternal cls_attr, CfgOrigin attr_orig |
            this.lookup(name, cls_attr, attr_orig)
            |
            cls_attr.isDescriptor() = false and value = cls_attr and origin = attr_orig
            or
            cls_attr.isDescriptor() = true and cls_attr.descriptorGetInstance(this.getSelf(), value, origin)
        )
    }

    private predicate lookup(string name, ObjectInternal value, CfgOrigin origin) {
        Types::getMro(this.getSelf().getClass()).startingAt(this.getStartClass()).getTail().lookup(name, value, origin)
    }

    pragma [noinline] override predicate binds(ObjectInternal instance, string name, ObjectInternal descriptor) {
        descriptor.isDescriptor() = true and
        this.lookup(name, descriptor, _) and
        instance = this.getSelf() and
        receiver_type(_, name, this, _)
    }

    override int length() {
        none()
    }

}

