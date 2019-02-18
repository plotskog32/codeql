import cil
import semmle.code.cil.CallableReturns

predicate relevantMethod(CIL::Method m) {
  m.getName() = "GetEncoder"
  or
  m.getName() = "get_Item"
  or
  m.getDeclaringType().getName() = "ThrowHelper"
}

query predicate alwaysNull(string s, string d) {
  exists(CIL::Method m |
    alwaysNullMethod(m) and
    s = m.toStringWithTypes() and
    relevantMethod(m) and
    d = m.getImplementation().getDisassembly()
  )
}

query predicate alwaysNonNull(string s) {
  exists(CIL::Method m | alwaysNotNullMethod(m) and s = m.toStringWithTypes() and relevantMethod(m))
}

query predicate alwaysThrows(string s, string ex, string d) {
  exists(CIL::Method m, CIL::Type t | alwaysThrowsException(m, t) and relevantMethod(m) |
    s = m.toStringWithTypes() and
    ex = t.toStringWithTypes() and
    d = m.getImplementation().getDisassembly()
  )
}
