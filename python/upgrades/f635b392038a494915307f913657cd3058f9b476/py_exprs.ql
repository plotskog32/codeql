class Location extends @location {
    /** Gets the start line of this location */
    int getStartLine() {
        locations_default(this, _, result, _, _, _) or
        locations_ast(this, _, result, _, _, _)
    }

    /** Gets the start column of this location */
    int getStartColumn() {
        locations_default(this, _, _, result, _, _) or
        locations_ast(this, _, _, result, _, _)
    }

    string toString() { result = "<some file>" + ":" + this.getStartLine().toString() }
}

class Expr_ extends @py_expr {
    string toString() { result = "Expr" }

    Location getLocation() { py_locations(result, this) }
}

class ExprParent_ extends @py_expr_parent {
    string toString() { result = "ExprParent" }
}

class ExprList_ extends @py_expr_list {
    /** Gets the nth item of this expression list */
    Expr_ getItem(int index) { py_exprs(result, _, this, index) }

    string toString() { result = "ExprList" }
}

class Parameter_ extends @py_parameter {
    string toString() { result = "Parameter" }

    Location getLocation() { result = this.(Expr_).getLocation() }
}

class ParameterList extends @py_parameter_list {
    /** Gets the nth parameter */
    Parameter_ getItem(int index) {
        /* Item can be a Name or a Tuple, both of which are expressions */
        py_exprs(result, _, this, index)
    }

    string toString() { result = "ParameterList" }
}

class Arguments_ extends @py_arguments {
    /** Gets the keyword-only default values of this parameters definition. */
    ExprList_ getKwDefaults() { py_expr_lists(result, this, 0) }

    /** Gets the nth keyword-only default value of this parameters definition. */
    Expr_ getKwDefault(int index) { result = this.getKwDefaults().getItem(index) }

    /** Gets the default values of this parameters definition. */
    ExprList_ getDefaults() { py_expr_lists(result, this, 1) }

    /** Gets the nth default value of this parameters definition. */
    Expr_ getDefault(int index) { result = this.getDefaults().getItem(index) }

    string toString() { result = "Arguments" }
}

class Function_ extends @py_Function {
    /** Gets the name of this function. */
    string getName() { py_strs(result, this, 0) }

    /** Gets the positional parameter list of this function. */
    ParameterList getArgs() { py_parameter_lists(result, this) }

    /** Gets the nth positional parameter of this function. */
    Parameter_ getArg(int index) { result = this.getArgs().getItem(index) }

    /** Gets the tuple (*) parameter of this function. */
    Expr_ getVararg() { py_exprs(result, _, this, 2) }

    /** Gets the keyword-only parameter list of this function. */
    ExprList_ getKwonlyargs() { py_expr_lists(result, this, 3) }

    /** Gets the nth keyword-only parameter of this function. */
    Expr_ getKwonlyarg(int index) { result = this.getKwonlyargs().getItem(index) }

    /** Gets the dictionary (**) parameter of this function. */
    Expr_ getKwarg() { py_exprs(result, _, this, 4) }

    string toString() { result = "Function" }
}

/**
 * This class servers the same purpose as CallableExpr. CallableExpr is defined in Function.qll
 * To ease the burden of number of classes that needs to be implemented here, I make the class
 * hierarchy slightly different (that's why it's called Adjusted)
 */
abstract class CallableExprAdjusted extends Expr_ {
    /**
     * Gets The default values and annotations (type-hints) for the arguments of this callable.
     *
     * This predicate is called getArgs(), rather than getParameters() for compatibility with Python's AST module.
     */
    abstract Arguments_ getArgs();

    /** Gets the function scope of this code expression. */
    abstract Function_ getInnerScope();
}

class Lambda_ extends @py_Lambda, CallableExprAdjusted, Expr_ {
    /** Gets the arguments of this lambda expression. */
    override Arguments_ getArgs() { py_arguments(result, this) }

    /** Gets the function scope of this lambda expression. */
    override Function_ getInnerScope() { py_Functions(result, this) }

    override string toString() { result = "Lambda" }
}

class FunctionExpr_ extends @py_FunctionExpr, CallableExprAdjusted, Expr_ {
    /** Gets the parameters of this function definition. */
    override Arguments_ getArgs() { py_arguments(result, this) }

    /** Gets the function scope of this function definition. */
    override Function_ getInnerScope() { py_Functions(result, this) }

    override string toString() { result = "FunctionExpr" }
}

from Expr_ id, int kind, ExprParent_ parent, int oldidx, int newidx
where
    py_exprs(id, kind, parent, oldidx) and
    (
        not exists(Arguments_ args | args.getDefault(oldidx) = id) and
        not exists(Arguments_ args | args.getKwDefault(oldidx) = id) and
        newidx = oldidx
        or
        exists(Arguments_ args, CallableExprAdjusted callable |
            callable.getArgs() = args and
            args.getDefault(oldidx) = id and
            newidx = oldidx + count(callable.getInnerScope().getArg(_)) - count(args.getDefault(_))
        )
        or
        exists(Arguments_ args, CallableExprAdjusted callable |
            callable.getArgs() = args and
            args.getKwDefault(oldidx) = id and
            newidx =
                max(int i |
                    exists(Parameter_ param | param = callable.getInnerScope().getKwonlyarg(i) |
                        param.getLocation().getStartLine() < id.getLocation().getStartLine()
                        or
                        param.getLocation().getStartLine() = id.getLocation().getStartLine() and
                        param.getLocation().getStartColumn() < id.getLocation().getStartColumn()
                    )
                )
        )
    )
select id, kind, parent, newidx
