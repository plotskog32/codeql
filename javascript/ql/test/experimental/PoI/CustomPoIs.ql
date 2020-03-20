/**
 * @kind problem
 */

import javascript
import experimental.PoI.PoI::PoI
import DataFlow

class RouteHandlerPoI extends PoI {
  RouteHandlerPoI() { this = "RouteHandlerPoI" }

  override predicate is(Node l0) { l0 instanceof Express::RouteHandler }
}

class RouteHandlerAndSetupPoI extends PoI {
  RouteHandlerAndSetupPoI() { this = "RouteHandlerAndSetupPoI" }

  override predicate is(Node l0, Node l1, string t1) {
    l1.asExpr().(Express::RouteSetup).getARouteHandler() = l0 and t1 = "setup"
  }
}

class RouteSetupAndRouterAndRouteHandlerPoI extends PoI {
  RouteSetupAndRouterAndRouteHandlerPoI() { this = "RouteSetupAndRouterAndRouteHandlerPoI" }

  override predicate is(Node l0, Node l1, string t1, Node l2, string t2) {
    l0.asExpr().(Express::RouteSetup).getRouter().flow() = l1 and
    t1 = "router" and
    l0.asExpr().(Express::RouteSetup).getARouteHandler() = l2 and
    t2 = "routehandler"
  }
}

query predicate problems = alertQuery/6;