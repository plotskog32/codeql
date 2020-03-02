import python


library class PossibleAdvancedFormatString extends StrConst {

    PossibleAdvancedFormatString() {
        this.getText().matches("%{%}%")
    }

    private predicate field(int start, int end) {
        brace_pair(this, start, end) and
        this.getText().substring(start, end) != "{{}}"
    }

    /** Gets the number of the formatting field at [start, end) */
    int getFieldNumber(int start, int end) {
        result = this.fieldId(start, end).toInt()
        or
        this.implicitlyNumberedField(start, end) and
        result = count(int s | this.implicitlyNumberedField(s, _) and s < start)
    }

    /** Gets the text of the formatting field at [start, end) */
    string getField(int start, int end) {
        this.field(start, end) and
        result = this.getText().substring(start, end)
    }

    private string fieldId(int start, int end) {
        this.field(start, end) and
        (
            result = this.getText().substring(start, end).regexpCapture("\\{([^!:.\\[]+)[!:.\\[].*", 1)
            or
            result = this.getText().substring(start+1, end-1) and result.regexpMatch("[^!:.\\[]+")
        )
    }

    /** Gets the name of the formatting field at [start, end) */
    string getFieldName(int start, int end) {
        result = this.fieldId(start, end)
        and not exists(this.getFieldNumber(start, end))
    }

    private predicate implicitlyNumberedField(int start, int end) {
        this.field(start, end) and
        exists(string c | 
            start+1 = this.getText().indexOf(c) |
            c = "}" or c = ":" or c = "!" or c = "."
        )
    }

    /** Whether this format string has implicitly numbered fields */
    predicate isImplicitlyNumbered() {
        this.implicitlyNumberedField(_, _)
    }

    /** Whether this format string has explicitly numbered fields */
    predicate isExplicitlyNumbered() {
        exists(this.fieldId(_, _).toInt())
    }

}

predicate brace_sequence(PossibleAdvancedFormatString fmt, int index, int len) {
    exists(string text |
        text = fmt.getText() |
        text.charAt(index) = "{" and not text.charAt(index-1) = "{" and len = 1
        or
        text.charAt(index) = "{" and text.charAt(index-1) = "{" and brace_sequence(fmt, index-1, len-1)
    )
}

predicate escaped_brace(PossibleAdvancedFormatString fmt, int index) {
    exists(int len |
        brace_sequence(fmt, index, len) |
        len % 2 = 0
    )
}

predicate escaping_brace(PossibleAdvancedFormatString fmt, int index) {
    escaped_brace(fmt, index+1)
}

private predicate inner_brace_pair(PossibleAdvancedFormatString fmt, int start, int end) {
    not escaping_brace(fmt, start) and
    not escaped_brace(fmt, start) and
    fmt.getText().charAt(start) = "{" and
    exists(string pair | pair = fmt.getText().suffix(start).regexpCapture("(?s)(\\{([^{}]|\\{\\{)*+\\}).*", 1) |
        end = start + pair.length()
    )
}

private predicate brace_pair(PossibleAdvancedFormatString fmt, int start, int end) {
     inner_brace_pair(fmt, start, end) 
     or
     not escaping_brace(fmt, start) and
     not escaped_brace(fmt, start) and
     exists(string prefix, string postfix, int innerstart, int innerend |
          brace_pair(fmt, innerstart, innerend) and
          prefix = fmt.getText().regexpFind("\\{([^{}]|\\{\\{)+\\{", _, start)  and
          innerstart = start+prefix.length()-1 and
          postfix = fmt.getText().regexpFind("\\}([^{}]|\\}\\})*\\}", _, innerend-1) and
          end = innerend + postfix.length()-1
     )
}

private predicate advanced_format_call_objectapi(Call format_expr, PossibleAdvancedFormatString fmt, int args) {
    exists(CallNode call | 
        call = format_expr.getAFlowNode() |
        call.getFunction().refersTo(Object::builtin("format")) and call.getArg(0).refersTo(_, fmt.getAFlowNode()) and
        args = count(format_expr.getAnArg()) - 1
        or
        call.getFunction().(AttrNode).getObject("format").refersTo(_, fmt.getAFlowNode()) and
        args = count(format_expr.getAnArg())
    )
}

class AdvancedFormatString_objectapi extends PossibleAdvancedFormatString {

    AdvancedFormatString_objectapi() {
        advanced_format_call_objectapi(_, this, _)
    }

}

class AdvancedFormattingCall_objectapi extends Call {

    AdvancedFormattingCall_objectapi() {
        advanced_format_call_objectapi(this, _, _) 
    }

    /** Count of the arguments actually provided */
    int providedArgCount() {
        advanced_format_call_objectapi(this, _, result)
    }

    AdvancedFormatString_objectapi getAFormat() {
        advanced_format_call_objectapi(this, result, _)
    }

}

