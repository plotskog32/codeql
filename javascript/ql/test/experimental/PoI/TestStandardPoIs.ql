/**
 * @kind problem
 */

import javascript
import experimental.poi.PoI

class Config extends PoIConfiguration {
  Config() { this = "Config" }

  override predicate enabled(PoI poi) { poi instanceof UnpromotedRouteHandlerPoI }
}

query predicate problems = alertQuery/6;
