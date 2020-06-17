/**
 * Provides a taint-tracking configuration for reasoning about untrusted user input used in log entries.
 */

import javascript

module LogInjection {
  /**
   * A data flow source for user input used in log entries.
   */
  abstract class Source extends DataFlow::Node { }

  /**
   * A data flow sink for user input used in log entries.
   */
  abstract class Sink extends DataFlow::Node { }

  /**
   * A sanitizer for malicious user input used in log entries.
   */
  abstract class Sanitizer extends DataFlow::Node { }

  /**
   * A taint-tracking configuration for untrusted user input used in log entries.
   */
  class LogInjectionConfiguration extends TaintTracking::Configuration {
    LogInjectionConfiguration() { this = "LogInjection" }

    override predicate isSource(DataFlow::Node source) { source instanceof Source }

    override predicate isSink(DataFlow::Node sink) { sink instanceof Sink }

    override predicate isSanitizer(DataFlow::Node node) { node instanceof Sanitizer }
  }

  /**
   * A source of remote user controlled input.
   */
  class RemoteSource extends Source {
    RemoteSource() { this instanceof RemoteFlowSource }
  }

  /**
   * An source node representing a logging mechanism.
   */
  class ConsoleSource extends DataFlow::SourceNode {
    ConsoleSource() {
      exists(DataFlow::SourceNode node |
        node = this and this = DataFlow::moduleImport("console")
        or
        this = DataFlow::globalVarRef("console")
      )
    }
  }

  /**
   * A call to a logging mechanism. For example, the call could be in the following forms:
   * `console.log('hello')` or
   *
   * `let logger = console.log; `
   * `logger('hello')`  or
   *
   * `let logger = {info: console.log};`
   * `logger.info('hello')`
   */
  class LoggingCall extends DataFlow::CallNode {
    LoggingCall() {
      this = any(ConsoleSource console).getAMemberCall(getAStandardLoggerMethodName())
      or
      exists(DataFlow::SourceNode node, string propName |
        any(ConsoleSource console).getAPropertyRead() = node.getAPropertySource(propName) and
        this = node.getAPropertyRead(propName).getACall()
      )
      or
      this = any(LoggerCall call)
    }
  }

  /**
   * An argument to a logging mechanism.
   */
  class LoggingSink extends Sink {
    LoggingSink() { this = any(LoggingCall console).getAnArgument() }
  }

  /**
   * A call to `String.prototype.replace` that replaces `\n` is considered to sanitize the replaced string (reduce false positive).
   */
  class StringReplaceSanitizer extends Sanitizer {
    StringReplaceSanitizer() {
      exists(StringReplaceCall replace, string s |
        replace.replaces(s, "") and s.regexpMatch("\\n")
      |
        this = replace
      )
    }
  }

  /**
   * A call to an HTML sanitizer is considered to sanitize the user input.
   */
  class HtmlSanitizer extends Sanitizer {
    HtmlSanitizer() { this instanceof HtmlSanitizerCall }
  }
}
