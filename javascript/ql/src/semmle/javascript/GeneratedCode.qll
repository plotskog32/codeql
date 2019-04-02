/**
 * Provides classes for detecting generated code.
 */

import javascript
import semmle.javascript.frameworks.Bundling
import semmle.javascript.frameworks.Emscripten
import semmle.javascript.frameworks.GWT
import semmle.javascript.SourceMaps

/**
 * A comment that marks generated code.
 */
abstract class GeneratedCodeMarkerComment extends Comment { }

/**
 * A source mapping comment, viewed as a marker comment indicating generated code.
 */
private class SourceMappingCommentMarkerComment extends GeneratedCodeMarkerComment {
  SourceMappingCommentMarkerComment() { this instanceof SourceMappingComment }
}

/**
 * A marker comment left by a known code generator.
 */
class CodeGeneratorMarkerComment extends GeneratedCodeMarkerComment {
  CodeGeneratorMarkerComment() { codeGeneratorMarkerComment(this, _) }

  /** Gets the name of the code generator that left this marker comment. */
  string getGeneratorName() { codeGeneratorMarkerComment(this, result) }
}

/**
 * Holds if `c` is a comment left by code generator `tool`.
 */
private predicate codeGeneratorMarkerComment(Comment c, string tool) {
  exists(string toolPattern |
    toolPattern = "js_of_ocaml|CoffeeScript|LiveScript|dart2js|ANTLR|PEG\\.js|Opal|JSX|jison(?:-lex)?|(?:Microsoft \\(R\\) AutoRest Code Generator)|purs" and
    tool = c
          .getText()
          .regexpCapture("(?s)[\\s*]*(?:parser |Code )?[gG]eneratedy? (?:from .*)?by (" +
              toolPattern + ")\\b.*", 1)
  )
}

/**
 * A generic generated code marker comment.
 */
private class GenericGeneratedCodeMarkerComment extends GeneratedCodeMarkerComment {
  GenericGeneratedCodeMarkerComment() {
    exists(string line | line = getLine(_) |
      exists(string entity, string was, string automatically |
        entity = "code|file|class|interface|art[ei]fact|module|script" and
        was = "was|is|has been" and
        automatically = "automatically |mechanically |auto[- ]?" and
        line
            .regexpMatch("(?i).*\\b(This|The following) (" + entity + ") (" + was + ") (" +
                automatically + ")?gener(e?)ated\\b.*")
      )
    )
  }
}

/**
 * A comment warning against modifications, viewed as a marker comment indicating generated code.
 */
private class DontModifyMarkerComment extends GeneratedCodeMarkerComment {
  DontModifyMarkerComment() {
    exists(string line | line = getLine(_) |
      line.regexpMatch("(?i).*\\bGenerated by\\b.*\\bDo not edit\\b.*") or
      line.regexpMatch("(?i).*\\bAny modifications to this file will be lost\\b.*")
    )
  }
}

/** A script that looks like it was generated by dart2js. */
private class DartGeneratedTopLevel extends TopLevel {
  DartGeneratedTopLevel() {
    exists(VarAccess deferredInit | deferredInit.getTopLevel() = this |
      deferredInit.getName() = "$dart_deferred_initializers$" or
      deferredInit.getName() = "$dart_deferred_initializers"
    )
  }
}

/**
 * Holds if `tl` has unusually many or unusually complicated function invocations, which is
 * often a sign of generated code.
 */
private predicate hasManyInvocations(TopLevel tl) {
  // heuristic: more than 100 arguments per line means it's probably generated
  exists(int nl, int na |
    nl = tl.getNumberOfLines() and
    nl > 0 and
    na = sum(InvokeExpr invk | tl = invk.getTopLevel() | invk.getNumArgument()) and
    na.(float) / nl > 100
  )
}

/**
 * Holds if `f` is side effect free, and full of primitive literals, which is often a sign of generated data code.
 */
private predicate isData(File f) {
  // heuristic: `f` has more than 1000 primitive literal expressions ...
  count(SyntacticConstants::PrimitiveLiteralConstant e | e.getFile() = f) > 1000 and
  // ... but no expressions with side effects ...
  not exists(Expr e |
    e.getFile() = f and
    e.isImpure() and
    // ... except for variable initializers
    not e instanceof VariableDeclarator
  )
}

/**
 * Holds if `f` is a generated HTML file.
 */
private predicate isGeneratedHtml(File f) {
  exists(HTML::Element e |
    e.getFile() = f and
    e.getName() = "meta" and
    e.getAttributeByName("name").getValue() = "generator"
  )
  or
  20 < countStartingHtmlElements(f, _)
}

/**
 * Gets an element that starts at line `l` in file `f`.
 */
private HTML::Element getAStartingElement(File f, int l) {
  result.getFile() = f and result.getLocation().getStartLine() = l
}


/**
 * Gets the number of HTML elements that start at line `l` in file `f`.
 */
private int countStartingHtmlElements(File f, int l) {
  result = strictcount(getAStartingElement(f, l))
}

/**
 * Holds if `tl` looks like it contains generated code.
 */
predicate isGenerated(TopLevel tl) {
  tl.isMinified() or
  isBundle(tl) or
  tl instanceof GWTGeneratedTopLevel or
  tl instanceof DartGeneratedTopLevel or
  exists(GeneratedCodeMarkerComment gcmc | tl = gcmc.getTopLevel()) or
  hasManyInvocations(tl) or
  isData(tl.getFile()) or
  isGeneratedHtml(tl.getFile())
}

/**
 * Holds if `file` look like it contains generated code.
 */
predicate isGeneratedCode(File file) {
  isGenerated(file.getATopLevel()) or
  isGeneratedHtml(file)
}
