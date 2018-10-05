/**
 * Provides a taint tracking configuration for reasoning about file data in outbound remote requests.
 */
import javascript
import semmle.javascript.security.dataflow.RemoteFlowSources

module FileAccessToHttp {

  /**
   * A data flow source for file data in outbound remote requests.
   */
  abstract class Source extends DataFlow::Node { }

  /**
   * A data flow sink for file data in outbound remote requests.
   */
  abstract class Sink extends DataFlow::Node { }

  /**
   * A sanitizer for file data in outbound remote requests.
   */
  abstract class Sanitizer extends DataFlow::Node { }

  /**
   * A taint tracking configuration for file data in outbound remote requests.
   */
  class Configuration extends TaintTracking::Configuration {
    Configuration() {
      this = "FileAccessToHttp"
    }

    override predicate isSource(DataFlow::Node source) {
      source instanceof Source
    }

    override predicate isSink(DataFlow::Node sink) {
      sink instanceof Sink
    }

    override predicate isSanitizer(DataFlow::Node node) {
      super.isSanitizer(node) or
      node instanceof Sanitizer
    }

    /** additional taint step that taints an object wrapping a source */
    override predicate isAdditionalTaintStep(DataFlow::Node pred, DataFlow::Node succ) {
      (
          pred = DataFlow::valueNode(_) or
          pred = DataFlow::parameterNode(_) or
          pred instanceof DataFlow::PropRead
      ) and
      exists (DataFlow::PropWrite pwr |
        succ = pwr.getBase() and
        pred = pwr.getRhs()
      )
    }
  }

  /**
   * A file access parameter, considered as a flow source for file data in outbound remote requests.
   */
  private class FileAccessArgumentAsSource extends Source {
    FileAccessArgumentAsSource() {  
      exists(FileSystemReadAccess src |
        this = src.getADataNode().getALocalSource()
      )
    }
  }

  /**
   * The URL or data of a client request, considered as a flow source for file data in outbound remote requests.
   */
  private class ClientRequestUrlOrDataAsSink extends Sink {
    ClientRequestUrlOrDataAsSink () {
      exists (ClientRequest req |
        this = req.getUrl() or
        this = req.getADataNode()
      )
    }
  }
}