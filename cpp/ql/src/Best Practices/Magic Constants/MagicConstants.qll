import cpp
import semmle.code.cpp.AutogeneratedFile

/*
 * Counting nontrivial literal occurrences
 */

predicate trivialPositiveIntValue(string s) {
  // Small numbers
  s = [0 .. 20].toString() or
  s =
    [
      // Popular powers of two (decimal)
      "16", "24", "32", "64", "128", "256", "512", "1024", "2048", "4096", "16384", "32768",
      "65536", "1048576", "2147483648", "4294967296",
      // Popular powers of two, minus one (decimal)
      "15", "31", "63", "127", "255", "511", "1023", "2047", "4095", "16383", "32767", "65535",
      "1048577", "2147483647", "4294967295",
      // Popular powers of two (32-bit hex)
      "0x00000001", "0x00000002", "0x00000004", "0x00000008", "0x00000010", "0x00000020",
      "0x00000040", "0x00000080", "0x00000100", "0x00000200", "0x00000400", "0x00000800",
      "0x00001000", "0x00002000", "0x00004000", "0x00008000", "0x00010000", "0x00020000",
      "0x00040000", "0x00080000", "0x00100000", "0x00200000", "0x00400000", "0x00800000",
      "0x01000000", "0x02000000", "0x04000000", "0x08000000", "0x10000000", "0x20000000",
      "0x40000000", "0x80000000",
      // Popular powers of two, minus one (32-bit hex)
      "0x00000001", "0x00000003", "0x00000007", "0x0000000f", "0x0000001f", "0x0000003f",
      "0x0000007f", "0x000000ff", "0x000001ff", "0x000003ff", "0x000007ff", "0x00000fff",
      "0x00001fff", "0x00003fff", "0x00007fff", "0x0000ffff", "0x0001ffff", "0x0003ffff",
      "0x0007ffff", "0x000fffff", "0x001fffff", "0x003fffff", "0x007fffff", "0x00ffffff",
      "0x01ffffff", "0x03ffffff", "0x07ffffff", "0x0fffffff", "0x1fffffff", "0x3fffffff",
      "0x7fffffff", "0xffffffff",
      // Popular powers of two (16-bit hex)
      "0x0001", "0x0002", "0x0004", "0x0008", "0x0010", "0x0020", "0x0040", "0x0080", "0x0100",
      "0x0200", "0x0400", "0x0800", "0x1000", "0x2000", "0x4000", "0x8000",
      // Popular powers of two, minus one (16-bit hex)
      "0x0001", "0x0003", "0x0007", "0x000f", "0x001f", "0x003f", "0x007f", "0x00ff", "0x01ff",
      "0x03ff", "0x07ff", "0x0fff", "0x1fff", "0x3fff", "0x7fff", "0xffff",
      // Popular powers of two (8-bit hex)
      "0x01", "0x02", "0x04", "0x08", "0x10", "0x20", "0x40", "0x80",
      // Popular powers of two, minus one (8-bit hex)
      "0x01", "0x03", "0x07", "0x0f", "0x1f", "0x3f", "0x7f", "0xff", "0x00",
      // Powers of ten
      "10", "100", "1000", "10000", "100000", "1000000", "10000000", "100000000", "1000000000"
    ]
}

predicate trivialIntValue(string s) {
  trivialPositiveIntValue(s)
  or
  exists(string pos | trivialPositiveIntValue(pos) and s = "-" + pos)
}

predicate trivialLongValue(string s) { exists(string v | trivialIntValue(v) and s = v + "L") }

predicate intTrivial(Literal lit) { exists(string v | trivialIntValue(v) and v = lit.getValue()) }

predicate longTrivial(Literal lit) { exists(string v | trivialLongValue(v) and v = lit.getValue()) }

predicate powerOfTen(float f) {
  f = 10 or
  f = 100 or
  f = 1000 or
  f = 10000 or
  f = 100000 or
  f = 1000000 or
  f = 10000000 or
  f = 100000000 or
  f = 1000000000
}

predicate floatTrivial(Literal lit) {
  lit.getType() instanceof FloatingPointType and
  exists(string value, float f |
    lit.getValue() = value and
    f = value.toFloat() and
    (f.abs() <= 20.0 or powerOfTen(f))
  )
}

predicate charLiteral(Literal lit) { lit instanceof CharLiteral }

Type literalType(Literal literal) { result = literal.getType() }

predicate stringType(DerivedType t) {
  t.getBaseType() instanceof CharType
  or
  exists(SpecifiedType constCharType |
    t.getBaseType() = constCharType and
    constCharType.isConst() and
    constCharType.getBaseType() instanceof CharType
  )
}

predicate numberType(Type t) { t instanceof FloatingPointType or t instanceof IntegralType }

predicate stringLiteral(Literal literal) { literal instanceof StringLiteral }

predicate stringTrivial(Literal lit) {
  stringLiteral(lit) and
  lit.getValue().length() < 8
}

predicate joiningStringTrivial(Literal lit) {
  // We want to be more lenient with string literals that are being
  // joined together, because replacing sentence fragments with named
  // constants could actually result in code that is harder to
  // understand (which is against the spirit of these queries).
  stringLiteral(lit) and
  exists(FunctionCall fc |
    fc.getTarget().getName() = ["operator+", "operator<<"] and
    fc.getAnArgument().getAChild*() = lit
  ) and
  lit.getValue().length() < 16
}

predicate small(Literal lit) { lit.getValue().length() <= 1 }

predicate trivial(Literal lit) {
  charLiteral(lit) or
  intTrivial(lit) or
  floatTrivial(lit) or
  stringTrivial(lit) or
  joiningStringTrivial(lit) or
  longTrivial(lit) or
  small(lit)
}

private predicate isReferenceTo(Variable ref, Variable to) {
  exists(VariableAccess a |
    ref.getInitializer().getExpr().getConversion().(ReferenceToExpr).getExpr() = a and
    a.getTarget() = to
  )
}

private predicate variableNotModifiedAfterInitializer(Variable v) {
  not exists(VariableAccess a | a.getTarget() = v and a.isModified()) and
  not exists(AddressOfExpr e | e.getAddressable() = v) and
  forall(Variable v2 | isReferenceTo(v2, v) | variableNotModifiedAfterInitializer(v2))
}

predicate literalIsConstantInitializer(Literal literal, Variable f) {
  f.getInitializer().getExpr() = literal and
  variableNotModifiedAfterInitializer(f) and
  not f instanceof Parameter
}

predicate literalIsEnumInitializer(Literal literal) {
  exists(EnumConstant ec | ec.getInitializer().getExpr() = literal)
}

predicate literalInArrayInitializer(Literal literal) {
  exists(AggregateLiteral arrayInit | arrayInitializerChild(arrayInit, literal))
}

predicate arrayInitializerChild(AggregateLiteral parent, Expr e) {
  e = parent
  or
  exists(Expr mid | arrayInitializerChild(parent, mid) and e.getParent() = mid)
}

// i.e. not a constant folded expression
predicate literallyLiteral(Literal lit) {
  lit
      .getValueText()
      .regexpMatch(".*\".*|\\s*+[-+]?+\\s*+(0[xob][0-9a-fA-F]|[0-9])[0-9a-fA-F,._]*+([eE][-+]?+[0-9,._]*+)?+\\s*+[a-zA-Z]*+\\s*+")
}

predicate nonTrivialValue(string value, Literal literal) {
  value = literal.getValue() and
  not trivial(literal) and
  not literalIsConstantInitializer(literal, _) and
  not literalIsEnumInitializer(literal) and
  not literalInArrayInitializer(literal) and
  not literal.isAffectedByMacro() and
  literallyLiteral(literal)
}

predicate valueOccurrenceCount(string value, int n) {
  n =
    strictcount(Location loc |
      exists(Literal lit | lit.getLocation() = loc | nonTrivialValue(value, lit)) and
      // Exclude generated files (they do not have the same maintainability
      // concerns as ordinary source files)
      not loc.getFile() instanceof AutogeneratedFile
    ) and
  n > 20
}

predicate occurenceCount(Literal lit, string value, int n) {
  valueOccurrenceCount(value, n) and
  value = lit.getValue() and
  nonTrivialValue(_, lit)
}

/*
 * Literals repeated frequently
 */

predicate check(Literal lit, string value, int n, File f) {
  // Check that the literal is nontrivial
  not trivial(lit) and
  // Check that it is repeated a number of times
  occurenceCount(lit, value, n) and
  n > 20 and
  f = lit.getFile() and
  // Exclude generated files
  not f instanceof AutogeneratedFile
}

predicate checkWithFileCount(string value, int overallCount, int fileCount, File f) {
  fileCount =
    strictcount(Location loc |
      exists(Literal lit | lit.getLocation() = loc | check(lit, value, overallCount, f))
    )
}

predicate start(Literal lit, int startLine) {
  exists(Location l | l = lit.getLocation() and startLine = l.getStartLine())
}

predicate firstOccurrence(Literal lit, string value, int n) {
  exists(File f, int fileCount |
    checkWithFileCount(value, n, fileCount, f) and
    fileCount < 100 and
    check(lit, value, n, f) and
    not exists(Literal lit2, int start1, int start2 |
      check(lit2, value, n, f) and
      start(lit, start1) and
      start(lit2, start2) and
      start2 < start1
    )
  )
}

predicate magicConstant(Literal e, string msg) {
  exists(string value, int n |
    firstOccurrence(e, value, n) and
    msg =
      "Magic constant: literal '" + value + "' is repeated " + n.toString() +
        " times and should be encapsulated in a constant."
  )
}

/*
 * Literals where there is a defined constant with the same value
 */

predicate relevantVariable(Variable f, string value) {
  exists(Literal lit |
    not trivial(lit) and value = lit.getValue() and literalIsConstantInitializer(lit, f)
  )
}

predicate relevantCallable(Function f, string value) {
  exists(Literal lit |
    not trivial(lit) and value = lit.getValue() and lit.getEnclosingFunction() = f
  )
}

predicate isVisible(Variable field, Function fromCallable) {
  exists(string value |
    //public fields
    relevantVariable(field, value) and
    field.(MemberVariable).isPublic() and
    relevantCallable(fromCallable, value)
    or
    //in same class
    relevantVariable(field, value) and
    exists(Type t |
      t = field.getDeclaringType() and
      t = fromCallable.getDeclaringType()
    ) and
    relevantCallable(fromCallable, value)
    or
    //in subclass and not private
    relevantVariable(field, value) and
    not field.(MemberVariable).isPrivate() and
    exists(Class sup, Class sub |
      sup = field.getDeclaringType() and
      sub.getABaseClass+() = sup and
      sub = fromCallable.getDeclaringType()
    ) and
    relevantCallable(fromCallable, value)
  )
}

predicate canUseFieldInsteadOfLiteral(Variable constField, Literal magicLiteral) {
  exists(Literal initLiteral |
    literalIsConstantInitializer(initLiteral, constField) and
    not trivial(initLiteral) and
    not constField.getType().hasName("boolean") and
    exists(string value |
      value = initLiteral.getValue() and
      magicLiteral.getValue() = value
    ) and
    constField.getType() = magicLiteral.getType() and
    not literalIsConstantInitializer(magicLiteral, _) and
    exists(Function c |
      c = magicLiteral.getEnclosingFunction() and
      (
        constField.isTopLevel() and
        (not constField.isStatic() or constField.getFile() = c.getFile())
        or
        isVisible(constField, c)
      )
    )
  )
}

predicate literalInsteadOfConstant(
  Literal magicLiteral, string message, Variable constField, string linkText
) {
  canUseFieldInsteadOfLiteral(constField, magicLiteral) and
  message = "Literal value '" + magicLiteral.getValue() + "' used instead of constant $@." and
  linkText = constField.getName()
}
