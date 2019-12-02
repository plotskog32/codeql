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
  abstract private class NewBrowserObject extends BrowserObject {
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
      exists(string tp | tp = "BrowserWindow" or tp = "BrowserView" |
        asExpr().getType().hasUnderlyingType("electron", tp)
      )
    }
  }

  private DataFlow::SourceNode browserObject(DataFlow::TypeTracker t) {
    t.start() and
    result instanceof NewBrowserObject
    or
    exists(DataFlow::TypeTracker t2 | result = browserObject(t2).track(t2, t))
  }

  /**
   * A data flow node whose value may originate from a browser object instantiation.
   */
  private class BrowserObjectByFlow extends BrowserObject {
    BrowserObjectByFlow() { browserObject(DataFlow::TypeTracker::end()).flowsTo(this) }
  }

  /**
   * A reference to the `webContents` property of a browser object.
   */
  class WebContents extends DataFlow::SourceNode {
    WebContents() { this.(DataFlow::PropRead).accesses(any(BrowserObject bo), "webContents") }
  }

  /**
   * Provides classes and predicates for modelling Electron inter-process communication (IPC).
   * The Electron IPC are EventEmitters, but they also expose a number of methods on top of the standard EventEmitter.
   */
  private module IPC {
    DataFlow::SourceNode main() { result = DataFlow::moduleMember("electron", "ipcMain") }

    DataFlow::SourceNode renderer() { result = DataFlow::moduleMember("electron", "ipcRenderer") }

    /**
     * A model for the Main and Renderer process in an Electron app.
     */
    abstract class Process extends EventEmitter::EventEmitter { }

    /**
     * An instance of the Main process of an Electron app.
     * Communication in an electron app generally happens from the renderer process to the main process.
     */
    class MainProcess extends Process {
      MainProcess() { this = main() or this instanceof WebContents }
    }

    /**
     * An instance of the renderer process of an Electron app. 
     */
    class RendererProcess extends Process {
      RendererProcess() { this = renderer() }
    }
    
    /**
     * The `sender` property of the event in an IPC event handler. 
     * This sender is used to send a response back from the main process to the renderer.
     */
    class ProcessSender extends Process {
      ProcessSender() {
      	exists(IPCSendRegistration reg | reg.getEmitter() instanceof MainProcess | 
      	  this = reg.getABoundCallbackParameter(1, 0).getAPropertyRead("sender")	
      	)
      }
    }
    
    /**
     * A registration of an Electron IPC event handler.
     * Does mostly the same as an EventEmitter event handler, 
     * except that values can be returned through the `event.returnValue` property. 
     */
    class IPCSendRegistration extends EventEmitter::EventRegistration, DataFlow::MethodCallNode {
      override Process emitter;
      
      IPCSendRegistration() {
      	this = emitter.ref().getAMethodCall("on")
      }
      
      override string getChannel() {
      	this.getArgument(0).mayHaveStringValue(result)
      }
      
      override DataFlow::Node getCallbackParameter(int i) {
      	 result = this.getABoundCallbackParameter(1, i + 1) 
      }
      
      override DataFlow::Node getAReturnedValue(EventEmitter::EventDispatch dispatch) {
        dispatch.(DataFlow::InvokeNode).getCalleeName() = "sendSync" and
        result = this.getABoundCallbackParameter(1, 0).getAPropertyWrite("returnValue").getRhs()
      }
    }
    
    /**
     * A dispatch of an IPC event. 
     * An IPC event is sent from the Renderer to the Main process.
     * And a value can be returned through the `returnValue` property of the event (first parameter in the callback). 
     */
    class IPCDispatch extends EventEmitter::EventDispatch, DataFlow::InvokeNode {
	  override Process emitter;
	  
      IPCDispatch() {
      	exists(string methodName | methodName = "sendSync" or methodName = "send" | 
      	  this = emitter.ref().getAMemberCall(methodName)
      	)
      }
      
      override string getChannel() {
      	this.getArgument(0).mayHaveStringValue(result)
      }
      
      /**
       * Gets the `i`th dispatched argument to the event handler. 
       * The 0th parameter in the callback is a event generated by the IPC system, 
       * therefore these arguments start at 1. 
       */
      override DataFlow::Node getDispatchedArgument(int i) {
      	i >= 1 and 
      	result = getArgument(i)
      }
      
      /**
       * Holds if this dispatch can send an event to the given EventRegistration destination. 
       */
      override predicate canSendTo(EventEmitter::EventRegistration destination) {
      	this.getEmitter() instanceof RendererProcess and
      	destination.getEmitter() instanceof MainProcess
      	or
      	this.getEmitter() instanceof ProcessSender and
      	destination.getEmitter() instanceof RendererProcess
      }
    }
  }

  /**
   * A Node.js-style HTTP or HTTPS request made using an Electron module.
   */
  class ElectronClientRequest extends NodeJSLib::NodeJSClientRequest {
    override ElectronClientRequest::Range self;
  }

  module ElectronClientRequest {
    /**
     * A Node.js-style HTTP or HTTPS request made using an Electron module.
     *
     * Extends this class to add support for new Electron client-request APIs.
     */
    abstract class Range extends NodeJSLib::NodeJSClientRequest::Range { }
  }

  deprecated class CustomElectronClientRequest = ElectronClientRequest::Range;

  /**
   * A Node.js-style HTTP or HTTPS request made using `electron.ClientRequest`.
   */
  private class NewClientRequest extends ElectronClientRequest::Range {
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
