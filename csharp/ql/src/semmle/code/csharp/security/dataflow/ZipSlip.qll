/**
 * Provides a taint tracking configuration for reasoning about unsafe zip extraction.
 */

import csharp

module ZipSlip {
  import semmle.code.csharp.controlflow.Guards

  /**
   * A data flow source for unsafe zip extraction.
   */
  abstract class Source extends DataFlow::Node { }

  /**
   * A data flow sink for unsafe zip extraction.
   */
  abstract class Sink extends DataFlow::ExprNode { }

  /**
   * A sanitizer for unsafe zip extraction.
   */
  abstract class Sanitizer extends DataFlow::ExprNode { }

  /**
   * A guard for unsafe zip extraction.
   */
  abstract class BarrierGuard extends DataFlow::BarrierGuard { }

  /** A taint tracking configuration for Zip Slip */
  class TaintTrackingConfiguration extends TaintTracking::Configuration {
    TaintTrackingConfiguration() { this = "ZipSlipTaintTracking" }

    override predicate isSource(DataFlow::Node source) { source instanceof Source }

    override predicate isSink(DataFlow::Node sink) { sink instanceof Sink }

    override predicate isSanitizer(DataFlow::Node node) { node instanceof Sanitizer }

    override predicate isSanitizerGuard(DataFlow::BarrierGuard guard) {
      guard instanceof BarrierGuard
    }
  }

  /** An access to the `FullName` property of a `ZipArchiveEntry`. */
  class ArchiveFullNameSource extends Source {
    ArchiveFullNameSource() {
      exists(PropertyAccess pa | this.asExpr() = pa |
        pa.getTarget().getDeclaringType().hasQualifiedName("System.IO.Compression.ZipArchiveEntry") and
        pa.getTarget().getName() = "FullName"
      )
    }
  }

  /** An argument to the `ExtractToFile` extension method. */
  class ExtractToFileArgSink extends Sink {
    ExtractToFileArgSink() {
      exists(MethodCall mc |
        mc.getTarget().hasQualifiedName("System.IO.Compression.ZipFileExtensions", "ExtractToFile") and
        this.asExpr() = mc.getArgumentForName("destinationFileName")
      )
    }
  }

  /** A path argument to a `File.Open`, `File.OpenWrite`, or `File.Create` method call. */
  class FileOpenArgSink extends Sink {
    FileOpenArgSink() {
      exists(MethodCall mc |
        mc.getTarget().hasQualifiedName("System.IO.File", "Open") or
        mc.getTarget().hasQualifiedName("System.IO.File", "OpenWrite") or
        mc.getTarget().hasQualifiedName("System.IO.File", "Create")
      |
        this.asExpr() = mc.getArgumentForName("path")
      )
    }
  }

  /** A path argument to a call to the `FileStream` constructor. */
  class FileStreamArgSink extends Sink {
    FileStreamArgSink() {
      exists(ObjectCreation oc |
        oc.getTarget().getDeclaringType().hasQualifiedName("System.IO.FileStream")
      |
        this.asExpr() = oc.getArgumentForName("path")
      )
    }
  }

  /**
   * A path argument to a call to the `FileStream` constructor.
   *
   * This constructor can accept a tainted file name and subsequently be used to open a file stream.
   */
  class FileInfoArgSink extends Sink {
    FileInfoArgSink() {
      exists(ObjectCreation oc |
        oc.getTarget().getDeclaringType().hasQualifiedName("System.IO.FileInfo")
      |
        this.asExpr() = oc.getArgumentForName("fileName")
      )
    }
  }

  /**
   * A call to `GetFileName`.
   *
   * This is considered a sanitizer because it extracts just the file name, not the full path.
   */
  class GetFileNameSanitizer extends Sanitizer {
    GetFileNameSanitizer() {
      exists(MethodCall mc | mc.getTarget().hasQualifiedName("System.IO.Path", "GetFileName") |
        this.asExpr() = mc
      )
    }
  }

  /**
   * A call to `Substring`.
   *
   * This is considered a sanitizer because `Substring` may be used to extract a single component
   * of a path to avoid ZipSlip.
   */
  class SubstringSanitizer extends Sanitizer {
    SubstringSanitizer() {
      exists(MethodCall mc | mc.getTarget().hasQualifiedName("System.String", "Substring") |
        this.asExpr() = mc
      )
    }
  }

  /**
   * A call to `String.StartsWith()` that indicates that the tainted path value is being
   * validated to ensure that it occurs within a permitted output path.
   */
  class StringCheckGuard extends BarrierGuard, MethodCall {
    private Expr q;

    StringCheckGuard() {
      this.getTarget().hasQualifiedName("System.String", "StartsWith") and
      this.getQualifier() = q and
      // A StartsWith check against Path.Combine is not sufficient, because the ".." elements have
      // not yet been resolved.
      not exists(MethodCall combineCall |
        combineCall.getTarget().hasQualifiedName("System.IO.Path", "Combine") and
        DataFlow::localFlow(DataFlow::exprNode(combineCall), DataFlow::exprNode(q))
      )
    }

    override predicate checks(Expr e, AbstractValue v) {
      e = q and
      v.(AbstractValues::BooleanValue).getValue() = true
    }
  }
}
