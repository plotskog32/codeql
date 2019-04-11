import cpp

/**
 * Holds if `line` looks like a line of code.
 */
bindingset[line]
private predicate looksLikeCode(string line) {
  exists(string trimmed |
    // trim leading and trailing whitespace, and HTML codes: 
    //  * HTML entities in common notation (e.g. &amp;gt; and &amp;eacute;)
    //  * HTML entities in decimal notation (e.g. a&amp;#768;)
    //  * HTML entities in hexadecimal notation (e.g. &amp;#x705F;)
    trimmed = line.regexpReplaceAll("(?i)(^\\s+|&#?[a-z0-9]{1,31};|\\s+$)", "")
  |
    (
      (
        // Match comment lines ending with '{', '}' or ';'
        trimmed.regexpMatch(".*[{};]") and
        (
          // If this line looks like code because it ends with a closing
          // brace that's preceded by something other than whitespace ...
          trimmed.regexpMatch(".*.\\}")
          implies
          // ... then there has to be ") {" (or some variation)
          // on the line, suggesting it's a statement like `if`
          // or a function definition. Otherwise it's likely to be a
          // benign use of braces such as a JSON example or explanatory
          // pseudocode.
          trimmed.regexpMatch(".*(\\)|const|volatile|override|final|noexcept|&)\\s*\\{.*")
        )
      ) or (
        // Match comment lines that look like preprocessor code
        trimmed.regexpMatch("#\\s*(include|define|undef|if|ifdef|ifndef|elif|else|endif|error|pragma)\\b.*")
      )
    ) and (
      // Exclude lines that start with '>' or contain '@{' or '@}'.
      // To account for the code generated by protobuf, we also insist that the comment
      // does not begin with `optional` or `repeated` and end with a `;`, which would
      // normally be a quoted bit of literal `.proto` specification above the associated
      // declaration.
      // To account for emacs folding markers, we ignore any line containing
      // `{{{` or `}}}`.
      // Finally, some code tends to embed GUIDs in comments, so we also exclude those.
      not trimmed
        .regexpMatch("(>.*|.*[\\\\@][{}].*|(optional|repeated) .*;|.*(\\{\\{\\{|\\}\\}\\}).*|\\{[-0-9a-zA-Z]+\\})")
    )
  )
}

/**
 * Holds if there is a preprocessor directive on the line indicated by
 * `f` and `line`.
 */
private predicate preprocLine(File f, int line) {
  exists(PreprocessorDirective pd, Location l |
    pd.getLocation() = l and
    l.getFile() = f and
    l.getStartLine() = line
  )
}

/**
 * The line of a C++-style comment within its file `f`.
 */
private int lineInFile(CppStyleComment c, File f) {
  f = c.getFile() and
  result = c.getLocation().getStartLine() and

  // Ignore comments on the same line as a preprocessor directive.
  not preprocLine(f, result)
}

/**
 * The "comment block ID" for a comment line in a file.
 * The block ID is obtained by subtracting the line rank of the line from
 * the line itself, where the line rank is the (1-based) rank within `f`
 * of lines containing a C++-style comment. As a result, line comments on
 * consecutive lines are assigned the same block ID (as both line number
 * and line rank increase by 1 for each line), while intervening lines
 * without line comments would increase the line number without increasing
 * the rank and thus force a change of block ID.
 */
pragma[nomagic]
private int commentLineBlockID(File f, int line) {
  exists(int lineRank |
    line = rank[lineRank](lineInFile(_, f)) and
    result = line - lineRank
  )
}

/**
 * The comment ID of the given comment (on line `line` of file `f`).
 * The resulting number is meaningless, except that it will be the same
 * for all comments in a run of consecutive comment lines, and different
 * for separate runs.
 */
private int commentId(CppStyleComment c, File f, int line) {
  result = commentLineBlockID(f, line) and
  line = lineInFile(c, f)
}

/**
 * A contiguous block of comments.
 */
class CommentBlock extends Comment {
  CommentBlock() {
    (
      this instanceof CppStyleComment
      implies
      not exists(CppStyleComment pred, File f | lineInFile(pred, f) + 1 = lineInFile(this, f))
    ) and (
      // Ignore comments on the same line as a preprocessor directive.
      not exists(Location l |
        l = this.getLocation() and
        preprocLine(l.getFile(), l.getStartLine())
      )
    )
  }

  /**
   * Gets the `i`th comment associated with this comment block.
   */
  Comment getComment(int i) {
    i = 0 and result = this
    or
    exists(File f, int thisLine, int resultLine |
      commentId(this, f, thisLine) = commentId(result, f, resultLine)
    |
      i = resultLine - thisLine
    )
  }

  Comment lastComment() { result = this.getComment(max(int i | exists(this.getComment(i)))) }

  string getLine(int i) {
    this instanceof CStyleComment and
    result = this.getContents().regexpCapture("(?s)/\\*+(.*)\\*+/", 1).splitAt("\n", i)
    or
    this instanceof CppStyleComment and result = this.getComment(i).getContents().suffix(2)
  }

  int numLines() {
    result = strictcount(int i, string line | line = this.getLine(i) and line.trim() != "")
  }

  int numCodeLines() {
    result = strictcount(int i, string line | line = this.getLine(i) and looksLikeCode(line))
  }

  predicate isDocumentation() {
    // If a C-style comment starts each line with a *, then it's
    // probably documentation rather than code.
    this instanceof CStyleComment and
    forex(int i | i in [1 .. this.numLines() - 1] | this.getLine(i).trim().matches("*%"))
  }

  predicate isCommentedOutCode() {
    not this.isDocumentation() and
    not this.getFile().(HeaderFile).noTopLevelCode() and
    this.numCodeLines().(float) / this.numLines().(float) > 0.5
  }

  /**
   * Holds if this element is at the specified location.
   * The location spans column `startcolumn` of line `startline` to
   * column `endcolumn` of line `endline` in file `filepath`.
   * For more information, see
   * [Locations](https://help.semmle.com/QL/learn-ql/ql/locations.html).
   */
  predicate hasLocationInfo(
    string filepath, int startline, int startcolumn, int endline, int endcolumn
  ) {
    this.getLocation().hasLocationInfo(filepath, startline, startcolumn, _, _) and
    this.lastComment().getLocation().hasLocationInfo(_, _, _, endline, endcolumn)
  }
}

/**
 * A piece of commented-out code, identified using heuristics
 */
class CommentedOutCode extends CommentBlock {
  CommentedOutCode() { this.isCommentedOutCode() }
}
