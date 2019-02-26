import python
import semmle.python.security.strings.Untrusted

import TurboGears

private class ValidatedMethodParameter extends Parameter {

    ValidatedMethodParameter() {
        exists(string name, TurboGearsControllerMethod method |
            method.getArgByName(name) = this and
            method.getValidationDict().getItem(_).(KeyValuePair).getKey().(StrConst).getText() = name
        )
    }

}

class UnvalidatedControllerMethodParameter extends TaintSource {

    UnvalidatedControllerMethodParameter() {
        exists(Parameter p |
            any(TurboGearsControllerMethod m | not m.getName() = "onerror").getAnArg() = p and
            not p instanceof ValidatedMethodParameter and
            not p.isSelf() and
            p.(Name).getAFlowNode() = this
        )
    }

    override predicate isSourceOf(TaintKind kind) {
        kind instanceof UntrustedStringKind
    }

}

