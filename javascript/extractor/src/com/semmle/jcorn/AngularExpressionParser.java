package com.semmle.jcorn;

import java.util.ArrayList;
import java.util.List;

import com.semmle.js.ast.CallExpression;
import com.semmle.js.ast.Expression;
import com.semmle.js.ast.Position;
import com.semmle.js.ast.SourceLocation;

/**
 * Parser for Angular template expressions, based on the JS parser with
 * modified handling of the pipe operator.
 */
public class AngularExpressionParser extends Parser {
  public AngularExpressionParser(String input, int startPos) {
    super(new Options(), input, startPos);
  }

  @Override
  protected Expression buildBinary(
      int startPos,
      Position startLoc,
      Expression left,
      Expression right,
      String op,
      boolean logical) {
    // Angular pipe expression: `x|f:a` is desugared to `f(x, a)`
    if (op.equals("|")) {
      DestructuringErrors refDestructuringErrors = new DestructuringErrors();
      List<Expression> arguments = new ArrayList<>();
      arguments.add(left);
      while (this.type == TokenType.colon) {
        this.next();
        int argStartPos = this.pos;
        Position argStartLocation = this.curPosition();
        Expression arg = parseMaybeUnary(refDestructuringErrors, false);
        arguments.add(parseExprOp(arg, argStartPos, argStartLocation, TokenType.plusMin.binop, true));
      }
      SourceLocation loc = new SourceLocation(startLoc);
      return this.finishNode(new CallExpression(loc, right, null, arguments, false, false)); 
    }
    return super.buildBinary(startPos, startLoc, left, right, op, logical);
  }
}
