import python

import semmle.python.security.TaintTracking
import semmle.python.web.Http

abstract class BaseWebobRequest extends TaintKind {

    bindingset[this]
    BaseWebobRequest() { any() }

    override TaintKind getTaintOfAttribute(string name) {
        result instanceof ExternalStringDictKind and
        (
            name = "GET" or
            name = "POST" or
            name = "headers"
        )
        or
        result instanceof ExternalStringKind and
        (
            name = "body"
        )
    }

    override TaintKind getTaintOfMethodResult(string name) {
        result = this and
        (
            name = "copy" or
            name = "copy_get" or
            name = "copy_body"
        )
        or
        result instanceof ExternalStringKind and 
        (
            name = "as_bytes"
        )
    }

}

class WebobRequest extends BaseWebobRequest {

    WebobRequest() {
        this = "webob.Request"
    }

    override ClassObject getClass() {
        result = ModuleObject::named("webob.request").attr("Request")
    }

}
