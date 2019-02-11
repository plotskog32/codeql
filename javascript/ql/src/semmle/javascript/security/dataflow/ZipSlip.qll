/**
 * Provides a taint tracking configuration for reasoning about unsafe zip extraction.
 */

import javascript

module ZipSlip {
  /**
   * A data flow source for unsafe zip extraction.
   */
  abstract class Source extends DataFlow::Node { }

  /**
   * A data flow sink for unsafe zip extraction.
   */
  abstract class Sink extends DataFlow::Node { }

  /**
   * A sanitizer guard for unsafe zip extraction.
   */
  abstract class SanitizerGuard extends
    TaintTracking::SanitizerGuardNode,
    DataFlow::ValueNode { }

  /** A taint tracking configuration for Zip Slip */
  class Configuration extends TaintTracking::Configuration {
    Configuration() { this = "ZipSlip" }

    override predicate isSource(DataFlow::Node source) { source instanceof Source }

    override predicate isSink(DataFlow::Node sink) { sink instanceof Sink }

    override predicate isSanitizerGuard(TaintTracking::SanitizerGuardNode nd) {
      nd instanceof SanitizerGuard
    }
  }

  /**
   * An access to the filepath of an entry of a zipfile being extracted by
   * npm module `unzip`.
   */
  class UnzipEntrySource extends Source {
    UnzipEntrySource() {
      exists(DataFlow::MethodCallNode pipe, DataFlow::MethodCallNode on |
        pipe.getMethodName() = "pipe"
        and pipe.getArgument(0) = DataFlow::moduleImport("unzip").getAMemberCall("Parse")
        and on = pipe.getAMemberCall("on")
        and this = on.getCallback(1).getParameter(0).getAPropertyRead("path"))
    }
  }

  /**
   * A sink that is the path that a createWriteStream gets created at.
   * This is not covered by FileSystemWriteSink, because it is
   * required that a write actually takes place to the stream.
   * However, we want to consider even the bare createWriteStream to
   * be a zipslip vulnerability since it may truncate an existing file.
   */
  class CreateWriteStreamSink extends Sink {
    CreateWriteStreamSink() {
      this = DataFlow::moduleImport("fs").getAMemberCall("createWriteStream").getArgument(0)
    }
  }

  /** A sink that is a file path that gets written to. */
  class FileSystemWriteSink extends Sink {
    FileSystemWriteSink() {
      exists(FileSystemWriteAccess fsw | fsw.getAPathArgument() = this)
    }
  }

  /** A check that a path string does not include '..' */
  class NoParentDirSanitizerGuard extends SanitizerGuard {
    StringOps::Includes incl;

    NoParentDirSanitizerGuard() {  this = incl  }

    override predicate sanitizes(boolean outcome, Expr e) {
      incl.getPolarity().booleanNot() = outcome
      and incl.getBaseString().asExpr() = e
      and incl.getSubstring().mayHaveStringValue("..")
    }
  }
}
