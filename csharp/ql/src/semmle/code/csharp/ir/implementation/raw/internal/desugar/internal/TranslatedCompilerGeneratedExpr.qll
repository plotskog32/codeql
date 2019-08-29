/**
* Contains an abstract class, which is the super class  of all the classes that represent compiler 
* generated expressions.
*/

import csharp
private import TranslatedCompilerGeneratedElement
private import semmle.code.csharp.ir.implementation.raw.Instruction
private import semmle.code.csharp.ir.implementation.raw.internal.common.TranslatedExprBlueprint
private import semmle.code.csharp.ir.internal.IRCSharpLanguage as Language

abstract class TranslatedCompilerGeneratedExpr extends TranslatedCompilerGeneratedElement, 
                                                       TranslatedExprBlueprint {
  override string toString() {
    result = "compiler generated expr (" + generatedBy.toString() + ")"
  }
  
  abstract Type getResultType();
}
