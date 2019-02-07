import javascript

module Electron {
  /**
   * A `webPreferences` object.
   */
  class WebPreferences extends DataFlow::ObjectLiteralNode {
    WebPreferences() { this = any(NewBrowserObject nbo).getWebPreferences() }
  }

  /**
   * A data flow node that may contain a `BrowserWindow` or `BrowserView` object.
   */
  abstract class BrowserObject extends DataFlow::Node { }

  /**
   * An instantiation of `BrowserWindow` or `BrowserView`.
   */
  abstract private class NewBrowserObject extends BrowserObject, DataFlow::TrackedNode {
    DataFlow::NewNode self;

    NewBrowserObject() { this = self }

    /**
     * Gets the data flow node from which this instantiation takes its `webPreferences` object.
     */
    DataFlow::SourceNode getWebPreferences() {
      result = self.getOptionArgument(0, "webPreferences").getALocalSource()
    }
  }

  /**
   * An instantiation of `BrowserWindow`.
   */
  class BrowserWindow extends NewBrowserObject {
    BrowserWindow() {
      this = DataFlow::moduleMember("electron", "BrowserWindow").getAnInstantiation()
    }
  }

  /**
   * An instantiation of `BrowserView`.
   */
  class BrowserView extends NewBrowserObject {
    BrowserView() { this = DataFlow::moduleMember("electron", "BrowserView").getAnInstantiation() }
  }

  /**
   * An expression of type `BrowserWindow` or `BrowserView`.
   */
  private class BrowserObjectByType extends BrowserObject {
    BrowserObjectByType() {
      exists (string tp | tp = "BrowserWindow" or tp = "BrowserView" |
        asExpr().getType().hasUnderlyingType("electron", tp)
      )
    }
  }

  /**
   * A data flow node whose value may originate from a browser object instantiation.
   */
  private class BrowserObjectByFlow extends BrowserObject {
    BrowserObjectByFlow() {
      any(NewBrowserObject nbo).flowsTo(this)
    }
  }

  /**
   * A Node.js-style HTTP or HTTPS request made using an Electron module.
   */
  abstract class CustomElectronClientRequest extends NodeJSLib::CustomNodeJSClientRequest { }

  /**
   * A Node.js-style HTTP or HTTPS request made using an Electron module.
   */
  class ElectronClientRequest extends NodeJSLib::NodeJSClientRequest {
    ElectronClientRequest() { this instanceof CustomElectronClientRequest }
  }

  /**
   * A Node.js-style HTTP or HTTPS request made using `electron.ClientRequest`.
   */
  private class NewClientRequest extends CustomElectronClientRequest {
    NewClientRequest() {
      this = DataFlow::moduleMember("electron", "ClientRequest").getAnInstantiation() or
      this = DataFlow::moduleMember("electron", "net").getAMemberCall("request") // alias
    }

    override DataFlow::Node getUrl() {
      result = getArgument(0) or
      result = getOptionArgument(0, "url")
    }

    override DataFlow::Node getHost() {
      exists(string name |
        name = "host" or
        name = "hostname"
      |
        result = getOptionArgument(0, name)
      )
    }

    override DataFlow::Node getADataNode() {
      exists(string name | name = "write" or name = "end" |
        result = this.getAMethodCall(name).getArgument(0)
      )
    }
  }

  /**
   * A data flow node that is the parameter of a redirect callback for an HTTP or HTTPS request made by a Node.js process, for example `res` in `net.request(url).on('redirect', (res) => {})`.
   */
  private class ClientRequestRedirectEvent extends RemoteFlowSource {
    ClientRequestRedirectEvent() {
      exists(NodeJSLib::ClientRequestHandler handler |
        this = handler.getParameter(0) and
        handler.getAHandledEvent() = "redirect" and
        handler.getClientRequest() instanceof ElectronClientRequest
      )
    }

    override string getSourceType() { result = "ElectronClientRequest redirect event" }
  }
}
