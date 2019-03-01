private import internal.IRInternal
import FunctionIR
import cpp
import semmle.code.cpp.ir.implementation.TempVariableTag
private import semmle.code.cpp.ir.internal.IRUtilities
private import semmle.code.cpp.ir.internal.TempVariableTag
private import semmle.code.cpp.ir.internal.TIRVariable

IRUserVariable getIRUserVariable(Function func, Variable var) {
  result.getVariable() = var and
  result.getEnclosingFunction() = func
}

/**
 * Represents a variable referenced by the IR for a function. The variable may
 * be a user-declared variable (`IRUserVariable`) or a temporary variable
 * generated by the AST-to-IR translation (`IRTempVariable`).
 */
abstract class IRVariable extends TIRVariable {
  Function func;

  abstract string toString();

  /**
   * Gets the type of the variable.
   */
  abstract Type getType();

  /**
   * Gets the AST node that declared this variable, or that introduced this
   * variable as part of the AST-to-IR translation.
   */
  abstract Locatable getAST();

  /**
   * Gets an identifier string for the variable. This identifier is unique
   * within the function.
   */
  abstract string getUniqueId();
  
  /**
   * Gets the source location of this variable.
   */
  final Location getLocation() {
    result = getAST().getLocation()
  }

  /**
   * Gets the IR for the function that references this variable.
   */
  final FunctionIR getEnclosingFunctionIR() {
    result.getFunction() = func
  }

  /**
   * Gets the function that references this variable.
   */
  final Function getEnclosingFunction() {
    result = func
  }
}

/**
 * Represents a user-declared variable referenced by the IR for a function.
 */
abstract class IRUserVariable extends IRVariable {
  Variable var;

  override final string toString() {
    result = var.toString()
  }

  override final Type getType() {
    result = getVariableType(var)
  }

  override final Locatable getAST() {
    result = var
  }

  override final string getUniqueId() {
    result = var.toString() + " " + var.getLocation().toString()
  }

  /**
   * Gets the original user-declared variable.
   */
  final Variable getVariable() {
    result = var
  }
}

/**
 * Represents a variable (user-declared or temporary) that is allocated on the
 * stack. This includes all parameters, non-static local variables, and
 * temporary variables.
 */
abstract class IRAutomaticVariable extends IRVariable {
}

class IRAutomaticUserVariable extends IRUserVariable, IRAutomaticVariable,
  TIRAutomaticUserVariable {
  LocalScopeVariable localVar;

  IRAutomaticUserVariable() {
    this = TIRAutomaticUserVariable(localVar, func) and
    var = localVar
  }

  final LocalScopeVariable getLocalVariable() {
    result = localVar
  }
}

class IRStaticUserVariable extends IRUserVariable, TIRStaticUserVariable {
  IRStaticUserVariable() {
    this = TIRStaticUserVariable(var, func)
  }
}

IRTempVariable getIRTempVariable(Locatable ast, TempVariableTag tag) {
  result.getAST() = ast and
  result.getTag() = tag
}

class IRTempVariable extends IRVariable, IRAutomaticVariable, TIRTempVariable {
  Locatable ast;
  TempVariableTag tag;
  Type type;

  IRTempVariable() {
    this = TIRTempVariable(func, ast, tag, type)
  }

  override final Type getType() {
    result = type
  }

  override final Locatable getAST() {
    result = ast
  }

  override final string getUniqueId() {
    result = "Temp: " + Construction::getTempVariableUniqueId(this)
  }

  final TempVariableTag getTag() {
    result = tag
  }

  override string toString() {
    result = getBaseString() + ast.getLocation().getStartLine().toString() + ":" +
      ast.getLocation().getStartColumn().toString()
  }

  string getBaseString() {
    result = "#temp"
  }
}

class IRReturnVariable extends IRTempVariable {
  IRReturnVariable() {
    tag = ReturnValueTempVar()
  }

  override final string toString() {
    result = "#return"
  }
}

class IRThrowVariable extends IRTempVariable {
  IRThrowVariable() {
    tag = ThrowTempVar()
  }

  override string getBaseString() {
    result = "#throw"
  }
}
