/**
 * @name Missing regular expression anchor
 * @description Regular expressions without anchors can be vulnerable to bypassing.
 * @kind problem
 * @problem.severity warning
 * @precision medium
 * @id js/regex/missing-regexp-anchor
 * @tags correctness
 *       security
 *       external/cwe/cwe-20
 */

import javascript

/** Holds if `term` is one of the transitive left children of a regexp. */
predicate isLeftArmTerm(RegExpTerm term) {
  term.isRootTerm()
  or
  exists(RegExpTerm parent |
    term = parent.getChild(0) and
    isLeftArmTerm(parent)
  )
}

/** Holds if `term` is one of the transitive right children of a regexp. */
predicate isRightArmTerm(RegExpTerm term) {
  term.isRootTerm()
  or
  exists(RegExpTerm parent |
    term = parent.getLastChild() and
    isRightArmTerm(parent)
  )
}

/**
 * Holds if `term` is an anchor that is not the first or last node
 * in its tree.
 */
predicate isInteriorAnchor(RegExpAnchor term) {
  not isLeftArmTerm(term) and
  not isRightArmTerm(term)
}

/**
 * Holds if `term` contains an anchor that is not the first or last node
 * in its tree, such as `(foo|bar$|baz)`.
 */
predicate containsInteriorAnchor(RegExpTerm term) {
  isInteriorAnchor(term.getAChild*())
}

/**
 * Holds if `term` starts with a word boundary or lookbehind assertion,
 * indicating that it's not intended to be anchored on that side.
 */
predicate containsLeadingPseudoAnchor(RegExpSequence term) {
  exists(RegExpTerm child | child = term.getChild(0) |
    child instanceof RegExpWordBoundary or
    child instanceof RegExpNonWordBoundary or
    child instanceof RegExpLookbehind
  )
}

/**
 * Holds if `term` ends with a word boundary or lookahead assertion,
 * indicating that it's not intended to be anchored on that side.
 */
predicate containsTrailingPseudoAnchor(RegExpSequence term) {
  exists(RegExpTerm child | child = term.getLastChild() |
    child instanceof RegExpWordBoundary or
    child instanceof RegExpNonWordBoundary or
    child instanceof RegExpLookahead
  )
}

/**
 * Holds if `term` is an empty sequence, usually arising from
 * literals with a trailing alternative such as `foo|`.
 */
predicate isEmpty(RegExpSequence term) {
  term.getNumChild() = 0
}

/**
 * Holds if `term` contains a letter constant.
 *
 * We use this as a heuristic to filter out uninteresting results.
 */
predicate containsLetters(RegExpTerm term) {
  term.getAChild*().(RegExpConstant).getValue().regexpMatch(".*[a-zA-Z].*")
}

/**
 * Holds if `src` is a pattern for a collection of alternatives where
 * only the first or last alternative is anchored, indicating a
 * precedence mistake explained by `msg`.
 *
 * The canonical example of such a mistake is: `^a|b|c`, which is
 * parsed as `(^a)|(b)|(c)`.
 */
predicate isInterestingSemiAnchoredRegExpString(RegExpPatternSource src, string msg) {
  exists(RegExpAlt root, RegExpSequence anchoredTerm |
    root = src.getRegExpTerm() and
    not containsInteriorAnchor(root) and
    not isEmpty(root.getAChild()) and
    containsLetters(anchoredTerm) and
    (
      anchoredTerm = root.getChild(0) and
      anchoredTerm.getChild(0) instanceof RegExpCaret and
      not containsLeadingPseudoAnchor(root.getChild([ 1 .. root.getNumChild() - 1 ]))
      or
      anchoredTerm = root.getLastChild() and
      anchoredTerm.getLastChild() instanceof RegExpDollar and
      not containsTrailingPseudoAnchor(root.getChild([ 0 .. root.getNumChild() - 2 ]))
    ) and
    msg = "Misleading operator precedence. The subexpression '" + anchoredTerm.getRawValue() +
        "' is anchored, but the other parts of this regular expression are not"
  )
}

/**
 * Holds if `src` is an unanchored pattern for a URL, indicating a
 * mistake explained by `msg`.
 */
predicate isInterestingUnanchoredRegExpString(RegExpPatternSource src, string msg) {
  exists(string pattern | pattern = src.getPattern() |
    // a substring sequence of a protocol and subdomains, perhaps with some regex characters mixed in, followed by a known TLD
    pattern
        .regexpMatch("(?i)[():|?a-z0-9-\\\\./]+[.]" + RegExpPatterns::commonTLD() +
            "([/#?():]\\S*)?") and
    // without any anchors
    pattern.regexpMatch("[^$^]+") and
    // that is not used for capture or replace
    not exists(DataFlow::MethodCallNode mcn, string name | name = mcn.getMethodName() |
      name = "exec" and
      mcn = src.getARegExpObject().getAMethodCall() and
      exists(mcn.getAPropertyRead())
      or
      exists(DataFlow::Node arg |
        arg = mcn.getArgument(0) and
        (
          src.getARegExpObject().flowsTo(arg) or
          src.getAParse() = arg
        )
      |
        name = "replace"
        or
        name = "match" and exists(mcn.getAPropertyRead())
      )
    ) and
    msg = "When this is used as a regular expression on a URL, it may match anywhere, and arbitrary hosts may come before or after it."
  )
}

from DataFlow::Node nd, string msg
where
  isInterestingUnanchoredRegExpString(nd, msg)
  or
  isInterestingSemiAnchoredRegExpString(nd, msg)
select nd, msg
