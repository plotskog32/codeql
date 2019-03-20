import python
private import semmle.python.types.Builtins
private import semmle.python.objects.ObjectInternal
private import semmle.python.pointsto.PointsTo2
private import semmle.python.pointsto.PointsToContext2

newtype TObject =
    TBuiltinClassObject(Builtin bltn) {
        bltn.isClass() and not bltn = Builtin::unknownType()
    }
    or
    TBuiltinFunctionObject(Builtin bltn) { bltn.isFunction() }
    or
    TBuiltinMethodObject(Builtin bltn) { bltn.isMethod() }
    or
    TBuiltinModuleObject(Builtin bltn) { bltn.isModule() }
    or
    TBuiltinOpaqueObject(Builtin bltn) {
        not bltn.isClass() and not bltn.isFunction() and
        not bltn.isMethod() and not bltn.isModule() and
        not py_special_objects(bltn, _)
    }
    or
    TPythonFunctionObject(ControlFlowNode callable) {
        callable.getNode() instanceof CallableExpr
    }
    or
    TPythonClassObject(ControlFlowNode classexpr) {
        classexpr.getNode() instanceof ClassExpr
    }
    or
    TPackageObject(Folder f)
    or
    TPythonModule(Module m) { not m.isPackage() }
    or
    TTrue()
    or
    TFalse()
    or
    TNone()
    or
    TUnknown()
    or
    TUnknownClass()
    or
    TUndefined()
    or
    TInt(int n) {
        // Powers of 2 are used for flags
        is_power_2(n) or
        // And all combinations of flags up to 2^8
        n in [0..511] or
        // Any number explicitly mentioned in the source code.
        exists(Num num |
            n = num.getN().toInt() or
            exists(UnaryExpr neg | neg.getOp() instanceof USub and neg.getOperand() = num)
            and n = -num.getN().toInt()
        )
    }
    or
    TString(string s) {
        // Any string explicitly mentioned in the source code.
        exists(StrConst str |
            s = str.getText()
        )
        or
        // Any string from the library put in the DB by the extractor.
        exists(string quoted_string, Builtin bltn |
            quoted_string = bltn.getName() and
            s = quoted_string.regexpCapture("[bu]'([\\s\\S]*)'", 1)
        )
    }
    or
    TInstance(CallNode instantiation, ClassObjectInternal cls, PointsToContext2 context) {
        PointsTo2::points_to(instantiation.getFunction(), context, cls, _) and
        normal_class(cls)
    }

private predicate is_power_2(int n) {
    n = 1 or
    exists(int half | is_power_2(half) and n = half*2)
}

private predicate normal_class(ClassObjectInternal cls) {
    exists(Builtin bltn |
        bltn = cls.getBuiltin() |
        not bltn = Builtin::special(_)
    )
    //or
    //cls.getMro().inheritsFromType(false)
}

library class ClassDecl extends @py_object {

    ClassDecl() {
        this.(Builtin).isClass() and not this = Builtin::unknownType()
        or
        this.(ControlFlowNode).getNode() instanceof ClassExpr
    }

    string toString() {
        result = "ClassDecl"
    }

    private Class getClass() {
        result = this.(ControlFlowNode).getNode().(ClassExpr).getInnerScope()
    }

    predicate declaresAttribute(string name) {
        exists(this.(Builtin).getMember(name))
        or
        exists(SsaVariable var | name = var.getId() and var.getAUse() = this.getClass().getANormalExit())
    }

    string getName() {
        result = this.(Builtin).getName()
        or
        result = this.getClass().getName()
    }

}
