private import csharp
private import experimental.ir.implementation.TempVariableTag
private import experimental.ir.implementation.raw.internal.IRConstruction as Construction
private import experimental.ir.Util
private import IRCSharpLanguage as Language

newtype TIRVariable =
  TIRAutomaticUserVariable(LocalScopeVariable var, Callable callable) {
    Construction::functionHasIR(callable) and
    var.getCallable() = callable
  } or
  TIRTempVariable(
    Callable callable, Language::AST ast, TempVariableTag tag, Language::LanguageType type
  ) {
    Construction::hasTempVariable(callable, ast, tag, type)
  }
