/**
 * Provides all preprocessor directive classes.
 */

import Element

class PreprocessorDirective extends Element, @preprocessor_directive {
  override Location getALocation() { preprocessor_directive_location(this, result) }
}

/**
 * A `#pragma warning` directive.
 */
class PragmaWarningDirective extends PreprocessorDirective, @pragma_warning {
  /** Holds if this is a `#pragma warning restore` directive. */
  predicate restore() { pragma_warnings(this, 1) }

  /** Holds if this is a `#pragma warning disable` directive. */
  predicate disable() { pragma_warnings(this, 0) }

  /** Holds if this directive specifies error codes. */
  predicate hasErrorCodes() { exists(string s | pragma_warning_error_codes(this, s, _)) }

  /** Gets a specified error code from this directive. */
  string getAnErrorCode() { pragma_warning_error_codes(this, result, _) }

  override string toString() { result = "#pragma warning ..." }

  override string getAPrimaryQlClass() { result = "PragmaWarningDirective" }
}

/**
 * A `#pragma checksum` directive.
 */
class PragmaChecksumDirective extends PreprocessorDirective, @pragma_checksum {
  /** Gets the file name of this directive. */
  string getFileName() { pragma_checksums(this, result, _, _) }

  /** Gets the GUID of this directive. */
  string getGuid() { pragma_checksums(this, _, result, _) }

  /** Gets the checksum bytes of this directive. */
  string getBytes() { pragma_checksums(this, _, _, result) }

  override string toString() { result = "#pragma checksum ..." }

  override string getAPrimaryQlClass() { result = "PragmaChecksumDirective" }
}

/**
 * An `#define` directive.
 */
class DefineDirective extends PreprocessorDirective, @directive_define {
  /** Gets the name of the preprocessor symbol that is being set by this directive. */
  string getName() { directive_defines(this, result) }

  override string toString() { result = "#define ..." }

  override string getAPrimaryQlClass() { result = "DefineDirective" }
}

/**
 * An `#undef` directive.
 */
class UndefineDirective extends PreprocessorDirective, @directive_undefine {
  /** Gets the name of the preprocessor symbol that is being unset by this directive. */
  string getName() { directive_undefines(this, result) }

  override string toString() { result = "#undef ..." }

  override string getAPrimaryQlClass() { result = "UndefineDirective" }
}

/**
 * A `#warning` directive.
 */
class WarningDirective extends PreprocessorDirective, @directive_warning {
  /** Gets the text of the warning. */
  string getMessage() { directive_warnings(this, result) }

  override string toString() { result = "#warning ..." }

  override string getAPrimaryQlClass() { result = "WarningDirective" }
}

/**
 * An `#error` directive.
 */
class ErrorDirective extends PreprocessorDirective, @directive_error {
  /** Gets the text of the error. */
  string getMessage() { directive_errors(this, result) }

  override string toString() { result = "#error ..." }

  override string getAPrimaryQlClass() { result = "ErrorDirective" }
}

/**
 * A `#nullable` directive.
 */
class NullableDirective extends PreprocessorDirective, @directive_nullable {
  /** Holds if this is a `#nullable disable` directive. */
  predicate disable() { directive_nullables(this, 0, _) }

  /** Holds if this is a `#nullable enable` directive. */
  predicate enable() { directive_nullables(this, 1, _) }

  /** Holds if this is a `#nullable restore` directive. */
  predicate restore() { directive_nullables(this, 2, _) }

  /** Holds if this directive targets all nullable contexts. */
  predicate targetsAll() { directive_nullables(this, _, 0) }

  /** Holds if this directive targets nullable annotation context. */
  predicate targetsAnnotations() { directive_nullables(this, _, 1) }

  /** Holds if this directive targets nullable warning context. */
  predicate targetsWarnings() { directive_nullables(this, _, 2) }

  /** Gets the succeeding `#nullable` directive in the file, if any. */
  NullableDirective getSuccNullableDirective() {
    result =
      rank[1](NullableDirective next |
        next.getFile() = this.getFile() and
        next.getLocation().getStartLine() > this.getLocation().getStartLine()
      |
        next order by next.getLocation().getStartLine()
      )
  }

  /** Holds if there is a succeeding `#nullable` directive in the file. */
  predicate hasSuccNullableDirective() {
    exists(NullableDirective other |
      other.getFile() = this.getFile() and
      other.getLocation().getStartLine() > this.getLocation().getStartLine()
    )
  }

  override string toString() { result = "#nullable ..." }

  override string getAPrimaryQlClass() { result = "NullableDirective" }
}

/**
 * A `#line` directive, such as `#line default`, `#line hidden`, or `#line`
 * directive with line number.
 */
class LineDirective extends PreprocessorDirective, @directive_line {
  /** Gets the succeeding `#line` directive in the file, if any. */
  LineDirective getSuccLineDirective() {
    result =
      rank[1](LineDirective next |
        next.getFile() = this.getFile() and
        next.getLocation().getStartLine() > this.getLocation().getStartLine()
      |
        next order by next.getLocation().getStartLine()
      )
  }

  /** Holds if there is a succeeding `#line` directive in the file. */
  predicate hasSuccLineDirective() {
    exists(LineDirective other |
      other.getFile() = this.getFile() and
      other.getLocation().getStartLine() > this.getLocation().getStartLine()
    )
  }

  override string toString() { result = "#line ..." }

  override string getAPrimaryQlClass() { result = "LineDirective" }
}

/**
 * A `#line default` directive.
 */
class DefaultLineDirective extends LineDirective {
  DefaultLineDirective() { directive_lines(this, 0) }

  override string toString() { result = "#line default" }

  override string getAPrimaryQlClass() { result = "DefaultLineDirective" }
}

/**
 * A `#line hidden` directive.
 */
class HiddenLineDirective extends LineDirective {
  HiddenLineDirective() { directive_lines(this, 1) }

  override string toString() { result = "#line hidden" }

  override string getAPrimaryQlClass() { result = "HiddenLineDirective" }
}

/**
 * A numeric `#line` directive, such as `#line 200 file`
 */
class NumericLineDirective extends LineDirective {
  NumericLineDirective() { directive_lines(this, 2) }

  /** Gets the line number of this directive. */
  int getLine() { directive_line_values(this, result, _) }

  /** Holds if this directive specifies a file name. */
  predicate hasFileName() { this.getFileName() != "" }

  /** Gets the file name of this directive. */
  string getFileName() { directive_line_values(this, _, result) }

  override string getAPrimaryQlClass() { result = "NumericLineDirective" }
}
