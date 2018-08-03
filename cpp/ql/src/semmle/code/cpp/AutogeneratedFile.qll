import semmle.code.cpp.Comments
import semmle.code.cpp.File
import semmle.code.cpp.Preprocessor

/**
 * Holds if `c` is a comment which is usually seen in autogenerated files.
 * For example, comments containing 'autogenerated' or 'generated by'.
 */
predicate isAutogeneratedComment(Comment c) {
  c.getContents().regexpMatch("(?si).*(?:auto[ -]?generated|generated (?:by|file)|changes made in this file will be lost).*")
}

/**
 * Holds if the file contains `#line` pragmas that refer to a different file.
 * For example, in `parser.c` a pragma `#line 1 "parser.rl"`.
 * Such pragmas usually indicate that the file was automatically generated.
 */
predicate hasPragmaDifferentFile(File f) {
  exists (PreprocessorLine pl, string s |
    pl.getFile() = f and
    pl.getHead().splitAt(" ", 1) = s and /* Zero index is line number, one index is file reference */
    not ("\"" + f.getAbsolutePath() + "\"" = s))
}

/**
 * Holds if the file is probably an autogenerated file.
 *
 * A file is probably autogenerated if either of the following heuristics
 * hold:
 *   1. There is a comment in the start of the file that matches
 *      'autogenerated', 'generated by', or a similar phrase.
 *   2. There is a `#line` directive referring to a different file.
 */
class AutogeneratedFile extends File {
  cached AutogeneratedFile() {
    exists(int limit, int head |
      head <= 5 and
      limit = max(int line | locations_default(_, unresolveElement(this), head, _, line, _)) + 5
    |
      exists (Comment c | c.getFile() = this and c.getLocation().getStartLine() <= limit and isAutogeneratedComment(c))
    )
    or hasPragmaDifferentFile(this)
  }
}
