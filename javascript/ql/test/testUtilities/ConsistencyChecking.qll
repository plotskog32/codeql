import javascript

/**
 * A configuration for consistency checking.
 * Used to specify where the alerts are (the positives)
 * And which files should be included in the consistency-check.
 *
 * If no configuration is specified, then the default is that the all sinks from a `DataFlow::Configuration` are alerts, and all files are consistency-checked.
 */
abstract class ConsistencyConfiguration extends string {
  bindingset[this]
  ConsistencyConfiguration() { any() }

  /**
   * Gets an alert that should be checked for consistency.
   * The alert must match with a `NOT OK` comment.
   *
   * And likewise a `OK` comment must not have a corresponding alert on the same line.
   */
  DataFlow::Node getAnAlert() { result = getASink() }

  /**
   * Gets a file to include in the consistency checking.
   */
  File getAFile() { none() }
}

/**
 * A line-comment that asserts whether a result exists at that line or not.
 * Can optionally include `[INCONSISTENCY]` to indicate that a consistency issue is expected at the location
 */
private class AssertionComment extends LineComment {
  boolean shouldHaveAlert;

  AssertionComment() {
    if getText().regexpMatch("\\s*(NOT OK|BAD).*")
    then shouldHaveAlert = true
    else (
      getText().regexpMatch("\\s*(OK|GOOD).*") and shouldHaveAlert = false
    )
  }

  /**
   * Holds if there should be an alert at this location
   */
  predicate shouldHaveAlert() { shouldHaveAlert = true }

  /**
   * Holds if a consistency issue is expected at this location.
   */
  predicate expectConsistencyError() { getText().matches(["%[INCONSISTENCY]%"]) }
}

private DataFlow::Node getASink() { exists(DataFlow::Configuration cfg | cfg.hasFlow(_, result)) }

/**
 * Gets all the alerts for consistency consistency checking.
 */
private DataFlow::Node alerts() {
  result = any(ConsistencyConfiguration res).getAnAlert()
  or
  not exists(ConsistencyConfiguration r) and
  result = getASink()
}

/**
 * Gets an alert in `file` at `line`.
 * The `line` can be either the first or the last line of the alert.
 * And if no expression exists at `line`, then an alert on the next line is used.
 */
private DataFlow::Node getAlert(File file, int line) {
  result = alerts() and
  result.getFile() = file and
  (result.hasLocationInfo(_, _, _, line, _) or result.hasLocationInfo(_, line, _, _, _))
  or
  // The comment can be right above the result, so an alert also counts for the line above.
  not exists(Expr e |
    e.getFile() = file and [e.getLocation().getStartLine(), e.getLocation().getEndLine()] = line
  ) and
  result = alerts() and
  result.getFile() = file and
  result.hasLocationInfo(_, line + 1, _, _, _)
}

/**
 * Gets a comment that asserts either the existence or the absence of an alert in `file` at `line`.
 */
private AssertionComment getComment(File file, int line) {
  result.getLocation().getEndLine() = line and
  result.getFile() = file
}

/**
 * Holds if there is a false positive in `file` at `line`
 */
private predicate falsePositive(File file, int line, AssertionComment comment) {
  exists(getAlert(file, line)) and
  comment = getComment(file, line) and
  not comment.shouldHaveAlert()
}

/**
 * Holds if there is a false negative in `file` at `line`
 */
private predicate falseNegative(File file, int line, AssertionComment comment) {
  not exists(getAlert(file, line)) and
  comment = getComment(file, line) and
  comment.shouldHaveAlert()
}

/**
 * Gets a file that should be included for consistency checking.
 */
private File getATestFile() {
  not exists(any(ConsistencyConfiguration res).getAFile()) and
  result = any(LineComment comment).getFile()
  or
  result = any(ConsistencyConfiguration res).getAFile()
}

/**
 * Gets a description of the configuration that has a sink in `file` at `line`.
 * Or the empty string
 */
bindingset[file, line]
private string getSinkDescription(File file, int line) {
  not exists(DataFlow::Configuration c | c.hasFlow(_, getAlert(file, line))) and result = ""
  or
  exists(DataFlow::Configuration c | c.hasFlow(_, getAlert(file, line)) | result = " for " + c)
}

/**
 * Holds if there is a consistency-issue at `location` with description `msg`.
 * The consistency issue an unexpected false positive/negative.
 * Or that false positive/negative was expected, and none were found.
 */
query predicate consistencyIssue(string location, string msg, string commentText) {
  exists(File file, int line |
    file = getATestFile() and location = file.getRelativePath() + ":" + line
  |
    exists(AssertionComment comment |
      comment.getText().trim() = commentText and comment = getComment(file, line)
    |
      falsePositive(file, line, comment) and
      not comment.expectConsistencyError() and
      msg = "did not expected an alert, but found an alert" + getSinkDescription(file, line)
      or
      falseNegative(file, line, comment) and
      not comment.expectConsistencyError() and
      msg = "expected an alert, but found none"
      or
      not falsePositive(file, line, comment) and
      not falseNegative(file, line, comment) and
      comment.expectConsistencyError() and
      msg = "expected consistency issue, but found no such issue (" + comment.getText().trim() + ")"
    )
  )
}
