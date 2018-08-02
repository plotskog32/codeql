/**
 * Provides classes that heuristically increase the extent of `HTTP::RouteHandler`.
 *
 * Note: This module should not be a permanent part of the standard library imports.
 */

import javascript
private import semmle.javascript.frameworks.ConnectExpressShared

/**
 * Adds `NodeJSLib::RouteHandlerCandidate` to the extent of `NodeJSLib::RouteHandler`.
 */
private class PromotedNodeJSLibCandidate extends NodeJSLib::RouteHandler, HTTP::Servers::StandardRouteHandler {

    PromotedNodeJSLibCandidate() {
      this instanceof NodeJSLib::RouteHandlerCandidate
    }

}

/**
 * Adds `ConnectExpressShared::RouteHandlerCandidate` to the extent of `Express::RouteHandler`.
 */
private class PromotedExpressCandidate extends Express::RouteHandler, HTTP::Servers::StandardRouteHandler {

    PromotedExpressCandidate() {
      this instanceof ConnectExpressShared::RouteHandlerCandidate
    }

    override SimpleParameter getRouteHandlerParameter(string kind) {
      result = ConnectExpressShared::getRouteHandlerParameter(getAstNode(), kind)
    }

}

/**
 * Adds `ConnectExpressShared::RouteHandlerCandidate` to the extent of `Connect::RouteHandler`.
 */
private class PromotedConnectCandidate extends Connect::RouteHandler, HTTP::Servers::StandardRouteHandler {

    PromotedConnectCandidate() {
      this instanceof ConnectExpressShared::RouteHandlerCandidate
    }

    override SimpleParameter getRouteHandlerParameter(string kind) {
      result = ConnectExpressShared::getRouteHandlerParameter(getAstNode(), kind)
    }

}