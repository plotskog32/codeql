
import python




private import semmle.python.objects.TObject
private import semmle.python.objects.ObjectInternal
private import semmle.python.pointsto.PointsTo
private import semmle.python.pointsto.PointsToContext
private import semmle.python.pointsto.MRO
private import semmle.python.types.Builtins

abstract class SequenceObjectInternal extends ObjectInternal {

    /** Gets the `n`th item of this sequence, if one exists. */
    abstract ObjectInternal getItem(int n);

    override boolean booleanValue() {
        this.length() = 0 and result = false
        or
        this.length() != 0 and result = true
    }

    override boolean isDescriptor() { result = false }

    pragma [noinline] override predicate descriptorGetClass(ObjectInternal cls, ObjectInternal value, CfgOrigin origin) { none() }

    pragma [noinline] override predicate descriptorGetInstance(ObjectInternal instance, ObjectInternal value, CfgOrigin origin) { none() }

    pragma [noinline] override predicate binds(ObjectInternal instance, string name, ObjectInternal descriptor) { none() }

    override string getName() { none() }

}

abstract class TupleObjectInternal extends SequenceObjectInternal {

    override string toString() {
        result = "(" + this.contents(0) + ")"
    }

    private string contents(int n) {
        n < 4 and n = this.length() and result = ""
        or
        n = 3 and this.length() > 3 and result = (this.length()-3).toString() + " more..."
        or
        result = this.getItem(n).toString() + ", " + this.contents(n+1)
    }

    /** Gets the class declaration for this object, if it is a declared class. */
    override ClassDecl getClassDeclaration() { none() }

    /** True if this "object" is a class. */
    override boolean isClass() { result = false }

    override ObjectInternal getClass() { result = ObjectInternal::builtin("tuple") }

    /** True if this "object" can be meaningfully analysed for
     * truth or false in comparisons. For example, `None` or `int` can be, but `int()`
     * or an unknown string cannot.
     */
    override predicate notTestableForEquality() { none() }

    /** Holds if `obj` is the result of calling `this` and `origin` is
     * the origin of `obj`.
     */
    override predicate callResult(ObjectInternal obj, CfgOrigin origin) { none() }

    /** Holds if `obj` is the result of calling `this` and `origin` is
     * the origin of `obj` with callee context `callee`.
     */
    override predicate callResult(PointsToContext callee, ObjectInternal obj, CfgOrigin origin) { none() }

    /** The integer value of things that have integer values.
     * That is, ints and bools.
     */
    override int intValue() { none() }

    /** The integer value of things that have integer values.
     * That is, strings.
     */
    override string strValue() { none() }

    override predicate calleeAndOffset(Function scope, int paramOffset) { none() }

    pragma [noinline] override predicate attribute(string name, ObjectInternal value, CfgOrigin origin) { none() }

    pragma [noinline] override predicate attributesUnknown() { none() }

    override predicate subscriptUnknown() { none() }

}

/** A tuple built-in to the interpreter, including the empty tuple. */
class BuiltinTupleObjectInternal extends TBuiltinTuple, TupleObjectInternal {

    override predicate introducedAt(ControlFlowNode node, PointsToContext context) {
        none()
    }

    override Builtin getBuiltin() {
        this = TBuiltinTuple(result)
    }

    override ControlFlowNode getOrigin() {
        none()
    }

    override ObjectInternal getItem(int n) {
        result.getBuiltin() = this.getBuiltin().getItem(n)
    }

    override int length() {
        exists(Builtin b |
            b = this.getBuiltin() and
            result = count(int n | exists(b.getItem(n)))
        )
    }
}

/** A tuple declared by a tuple expression in the Python source code */
class PythonTupleObjectInternal extends TPythonTuple, TupleObjectInternal {

    override predicate introducedAt(ControlFlowNode node, PointsToContext context) {
        this = TPythonTuple(node, context)
    }

    override Builtin getBuiltin() {
        none()
    }

    override ControlFlowNode getOrigin() {
        this = TPythonTuple(result, _)
    }

    override ObjectInternal getItem(int n) {
        exists(TupleNode t, PointsToContext context |
            this = TPythonTuple(t, context) and
            PointsToInternal::pointsTo(t.getElement(n), context, result, _)
        )
    }

    override int length() {
        exists(TupleNode t |
            this = TPythonTuple(t, _) and
            result = count(int n | exists(t.getElement(n)))
        )
    }

}

/** A tuple created by a `*` parameter */
class VarargsTupleObjectInternal extends TVarargsTuple,  TupleObjectInternal {

    override predicate introducedAt(ControlFlowNode node, PointsToContext context) {
        none()
    }

    override Builtin getBuiltin() {
        none()
    }

    override ControlFlowNode getOrigin() {
        none()
    }

    override ObjectInternal getItem(int n) {
        exists(CallNode call, PointsToContext context, int offset, int length |
            this = TVarargsTuple(call, context, offset, length) and
            n < length and
            InterProceduralPointsTo::positional_argument_points_to(call, offset+n, context, result, _)
        )
    }

    override int length() {
        this = TVarargsTuple(_, _, _, result)
    }
}


/** The `sys.version_info` object. We treat this specially to prevent premature pruning and
 * false positives when we are unsure of the actual version of Python that the code is expecting.
 */
class SysVersionInfoObjectInternal extends TSysVersionInfo, SequenceObjectInternal {

    override string toString() {
        result = "sys.version_info"
    }

    override ObjectInternal getItem(int n) {
        n = 0 and result = TInt(major_version())
        or
        n = 1 and result = TInt(minor_version())
    }

    override predicate introducedAt(ControlFlowNode node, PointsToContext context) { none() }

    /** Gets the class declaration for this object, if it is a declared class. */
    override ClassDecl getClassDeclaration() {
        result = Builtin::special("sys").getMember("version_info").getClass()
    }

    /** True if this "object" is a class. */
    override boolean isClass() { result = false }

    override ObjectInternal getClass() {
        result.getBuiltin() = this.getClassDeclaration()
    }

    override predicate notTestableForEquality() { none() }

    /** Gets the `Builtin` for this object, if any.
     * Objects (except unknown and undefined values) should attempt to return
     * exactly one result for either this method or `getOrigin()`.
     */
    override Builtin getBuiltin() { none() }

    /** Gets a control flow node that represents the source origin of this
     * objects.
     */
    override ControlFlowNode getOrigin() { none() }

    /** Holds if `obj` is the result of calling `this` and `origin` is
     * the origin of `obj`.
     */
    override predicate callResult(ObjectInternal obj, CfgOrigin origin) { none() }

    /** Holds if `obj` is the result of calling `this` and `origin` is
     * the origin of `obj` with callee context `callee`.
     */
    override predicate callResult(PointsToContext callee, ObjectInternal obj, CfgOrigin origin) { none() }

    /** The integer value of things that have integer values.
     * That is, ints and bools.
     */
    override int intValue() { none() }

    /** The integer value of things that have integer values.
     * That is, strings.
     */
    override string strValue() { none() }

    override predicate calleeAndOffset(Function scope, int paramOffset) { none() }

    override predicate attribute(string name, ObjectInternal value, CfgOrigin origin) { none() }

    override predicate attributesUnknown() { none() }

    override predicate subscriptUnknown() { none() }

    /** Gets the length of the sequence that this "object" represents.
     * Always returns a value for a sequence, will be -1 if object has no fixed length.
     */
    override int length() { result = 5 }

    override predicate functionAndOffset(CallableObjectInternal function, int offset) { none() }

}
