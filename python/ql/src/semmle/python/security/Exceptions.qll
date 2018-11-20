/**
 * Provides classes and predicates for tracking exceptions and information
 * associated with exceptions.
 */

import python
import semmle.python.security.TaintTracking
import semmle.python.security.strings.Basic

private ModuleObject theTracebackModule() {
    result.getName() = "traceback"
}

private FunctionObject traceback_function(string name) {
    result = theTracebackModule().getAttribute(name)
}

/**
 * This represents information relating to an exception, for instance the
 * message, arguments or parts of the exception traceback.
 */
class ExceptionInfo extends StringKind {

    ExceptionInfo() {
        this = "exception.info"
    }
}


/**
 * This kind represents exceptions themselves.
 */
class ExceptionKind extends TaintKind {

    ExceptionKind() {
        this = "exception.kind"
    }

    override TaintKind getTaintOfAttribute(string name) {
        name = "args" and result instanceof ExceptionInfoSequence
        or
        name = "message" and result instanceof ExceptionInfo
    }
}

/**
 * A source of exception objects, either explicitly created, or captured by an
 * `except` statement.
 */
class ExceptionSource extends TaintSource {

    ExceptionSource() {
        exists(ClassObject cls |
            cls.isSubclassOf(theExceptionType()) and
            this.(ControlFlowNode).refersTo(_, cls, _)
        )
        or
        this = any(ExceptStmt s).getName().getAFlowNode()
    }

    override string toString() {
        result = "exception.source"
    }

    override predicate isSourceOf(TaintKind kind) {
        kind instanceof ExceptionKind
    }
}

/**
 * Represents a sequence of pieces of information relating to an exception,
 * for instance the contents of the `args` attribute, or the stack trace.
 */
class ExceptionInfoSequence extends SequenceKind {
    ExceptionInfoSequence() {
        this.getItem() instanceof ExceptionInfo
    }
}


/**
 * Represents calls to functions in the `traceback` module that return
 * sequences of exception information.
 */
class CallToTracebackFunction extends TaintSource {

    CallToTracebackFunction() {
        exists(string name |
            name = "extract_tb" or
            name = "extract_stack" or
            name = "format_list" or
            name = "format_exception_only" or
            name = "format_exception" or
            name = "format_tb" or
            name = "format_stack"
        |
            this = traceback_function(name).getACall()
        )
    }

    override string toString() {
        result = "exception.info.sequence.source"
    }

    override predicate isSourceOf(TaintKind kind) {
        kind instanceof ExceptionInfoSequence
    }
}

/** 
 * Represents calls to functions in the `traceback` module that return a single
 * string of information about an exception.
 */
class FormattedTracebackSource extends TaintSource {

    FormattedTracebackSource() {
        this = traceback_function("format_exc").getACall()
    }

    override string toString() {
        result = "exception.info.source"
    }

    override predicate isSourceOf(TaintKind kind) {
        kind instanceof ExceptionInfo
    }
}
