/**
 * Provides classes for working with [socket.io](https://socket.io).
 */

import javascript

/**
 * Provides classes for working with server-side socket.io code
 * (npm package `socket.io`).
 *
 * We model three concepts: servers, namespaces, and sockets. A server
 * has one or more namespaces associated with it, each identified by
 * a path name. There is always a default namespace associated with the
 * path "/". Data flows between client and server side through sockets,
 * with each socket belonging to a namespace on a server.
 */
module SocketIO {
  /** Gets a data flow node that creates a new socket.io server. */
  private DataFlow::SourceNode newServer() {
    result = DataFlow::moduleImport("socket.io").getAnInvocation()
    or
    // alias for `Server`
    result = DataFlow::moduleImport("socket.io").getAMemberCall("listen")
  }

  /**
   * A common superclass for all socket-like objects on the serverside of SocketIO.
   * All of the subclasses can be used to send data to SocketIO clients (see the `SendNode` class).
   */
  abstract private class SocketIOObject extends DataFlow::SourceNode, EventEmitter::Range {
    /**
     * Gets a node that refers to this SocketIOObject object.
     */
    abstract DataFlow::SourceNode ref();

    /** Gets the namespace belonging to this object. */
    abstract NamespaceObject getNamespace();
  }

  /** A socket.io server. */
  class ServerObject extends SocketIOObject {
    ServerObject() { this = newServer() }

    /** Gets the default namespace of this server. */
    NamespaceObject getDefaultNamespace() { result = MkNamespace(this, "/") }

    /** Gets the default namespace of this server. */
    override NamespaceObject getNamespace() { result = getDefaultNamespace() }

    /** Gets the namespace with the given path of this server. */
    NamespaceObject getNamespace(string path) { result = MkNamespace(this, path) }

    /**
     * Gets a data flow node that may refer to the socket.io server created at `srv`.
     */
    private DataFlow::SourceNode server(DataFlow::TypeTracker t) {
      result = this and t.start()
      or
      exists(DataFlow::TypeTracker t2, DataFlow::SourceNode pred | pred = server(t2) |
        result = pred.track(t2, t)
        or
        // invocation of a chainable method
        exists(DataFlow::MethodCallNode mcn, string m |
          m = "adapter" or
          m = "attach" or
          m = "bind" or
          m = "listen" or
          m = "onconnection" or
          m = "origins" or
          m = "path" or
          m = "serveClient" or
          m = "set" or
          m = EventEmitter::chainableMethod()
        |
          mcn = pred.getAMethodCall(m) and
          // exclude getter versions
          exists(mcn.getAnArgument()) and
          result = mcn and
          t = t2.continue()
        )
      )
    }

    override DataFlow::SourceNode ref() { result = server(DataFlow::TypeTracker::end()) }
  }

  /** A data flow node that may produce (that is, create or return) a socket.io server. */
  class ServerNode extends DataFlow::SourceNode {
    ServerObject obj;

    ServerNode() { this = obj.ref() }

    /** Gets the server to which this node refers. */
    ServerObject getServer() { result = obj }
  }

  /**
   * Gets the name of a chainable method on socket.io namespace objects, which servers forward
   * to their default namespace.
   */
  private string namespaceChainableMethod() {
    result = "binary" or
    result = "clients" or
    result = "compress" or
    result = "emit" or
    result = "in" or
    result = "send" or
    result = "to" or
    result = "use" or
    result = "write" or
    result = EventEmitter::chainableMethod()
  }

  /**
   * A reference to a namespace object.
   */
  class NamespaceBase extends SocketIOObject {
    NamespaceObject ns;

    NamespaceBase() {
      exists(ServerObject srv |
        // namespace lookup on `srv`
        this = srv.ref().getAPropertyRead("sockets") and
        ns = srv.getDefaultNamespace()
        or
        exists(DataFlow::MethodCallNode mcn, string path |
          mcn = srv.ref().getAMethodCall("of") and
          mcn.getArgument(0).mayHaveStringValue(path) and
          this = mcn and
          ns = MkNamespace(srv, path)
        )
        or
        // invocation of a method that `srv` forwards to its default namespace
        this = srv.ref().getAMethodCall(namespaceChainableMethod()) and
        ns = srv.getDefaultNamespace()
      )
    }

    override NamespaceObject getNamespace() { result = ns }

    /**
     * Gets a data flow node that may refer to the socket.io namespace created at `ns`.
     */
    private DataFlow::SourceNode namespace(DataFlow::TypeTracker t) {
      t.start() and result = this
      or
      exists(DataFlow::SourceNode pred, DataFlow::TypeTracker t2 | pred = namespace(t2) |
        result = pred.track(t2, t)
        or
        // invocation of a chainable method
        result = pred.getAMethodCall(namespaceChainableMethod()) and
        t = t2.continue()
        or
        // invocation of chainable getter method
        exists(string m |
          m = "json" or
          m = "local" or
          m = "volatile"
        |
          result = pred.getAPropertyRead(m) and
          t = t2.continue()
        )
      )
    }

    override DataFlow::SourceNode ref() { result = namespace(DataFlow::TypeTracker::end()) }
  }

  /** A data flow node that may produce a namespace object. */
  class NamespaceNode extends DataFlow::SourceNode {
    NamespaceBase namespace;

    NamespaceNode() { this = namespace.ref() }

    /** Gets the namespace to which this node refers. */
    NamespaceObject getNamespace() { result = namespace.getNamespace() }
  }

  /** An socket object from SocketIO */
  class SocketObject extends SocketIOObject {
    NamespaceObject ns;

    SocketObject() {
      exists(DataFlow::SourceNode base, string connect, DataFlow::MethodCallNode on |
        (
          ns = any(ServerObject o | o.ref() = base).getDefaultNamespace() or
          ns = any(NamespaceBase o | o.ref() = base).getNamespace()
        ) and
        (connect = "connect" or connect = "connection")
      |
        on = base.getAMethodCall(EventEmitter::on()) and
        on.getArgument(0).mayHaveStringValue(connect) and
        this = on.getABoundCallbackParameter(1, 0)
      )
    }

    override NamespaceObject getNamespace() { result = ns }

    private DataFlow::SourceNode socket(DataFlow::TypeTracker t) {
      result = this and t.start()
      or
      exists(DataFlow::SourceNode pred, DataFlow::TypeTracker t2 | pred = socket(t2) |
        result = pred.track(t2, t)
        or
        // invocation of a chainable method
        exists(string m |
          m = "binary" or
          m = "compress" or
          m = "disconnect" or
          m = "emit" or
          m = "in" or
          m = "join" or
          m = "leave" or
          m = "send" or
          m = "to" or
          m = "use" or
          m = "write" or
          m = EventEmitter::chainableMethod()
        |
          result = pred.getAMethodCall(m) and
          t = t2.continue()
        )
        or
        // invocation of a chainable getter method
        exists(string m |
          m = "broadcast" or
          m = "json" or
          m = "local" or
          m = "volatile"
        |
          result = pred.getAPropertyRead(m) and
          t = t2.continue()
        )
      )
    }

    override DataFlow::SourceNode ref() { result = socket(DataFlow::TypeTracker::end()) }
  }

  /** A data flow node that may produce a socket object. */
  class SocketNode extends DataFlow::SourceNode {
    SocketObject socket;

    SocketNode() { this = socket.ref() }

    /** Gets the namespace to which this socket belongs. */
    NamespaceObject getNamespace() { result = socket.getNamespace() }
  }

  /**
   * A data flow node representing an API call that receives data from a client.
   */
  class ReceiveNode extends EventRegistration::Range, DataFlow::MethodCallNode {
    override SocketObject emitter;

    ReceiveNode() { this = emitter.ref().getAMethodCall(EventEmitter::on()) }

    /** Gets the socket through which data is received. */
    SocketObject getSocket() { result = emitter }

    /** Gets the callback that handles data received from a client. */
    DataFlow::FunctionNode getListener() { result = getCallback(1) }

    /** Gets the `i`th parameter through which data is received from a client. */
    override DataFlow::SourceNode getReceivedItem(int i) {
      exists(DataFlow::FunctionNode cb | cb = getListener() and result = cb.getParameter(i) |
        // exclude last parameter if it looks like a callback
        result != cb.getLastParameter() or not exists(result.getAnInvocation())
      )
    }

    override string getChannel() { this.getArgument(0).mayHaveStringValue(result) }
  }

  /** An acknowledgment callback when receiving a message. */
  class ReceiveCallback extends EventDispatch::Range, DataFlow::SourceNode {
    ReceiveNode rcv;

    ReceiveCallback() {
      this = rcv.getListener().getLastParameter() and
      exists(this.getAnInvocation()) and
      emitter = rcv.getEmitter()
    }

    override string getChannel() { result = rcv.getChannel() }

    override DataFlow::Node getSentItem(int i) { result = this.getACall().getArgument(i) }

    override SocketIOClient::SendCallback getAReceiver() {
      result.getSendNode().getAReceiver() = rcv
    }
  }

  /**
   * A data flow node representing data received from a client, viewed as remote user input.
   */
  private class ReceivedItemAsRemoteFlow extends RemoteFlowSource {
    ReceivedItemAsRemoteFlow() { this = any(ReceiveNode rercv).getReceivedItem(_) }

    override string getSourceType() { result = "socket.io client data" }

    override predicate isUserControlledObject() { any() }
  }

  /**
   * A data flow node representing an API call that sends data to a client.
   */
  class SendNode extends DataFlow::MethodCallNode, EventDispatch::Range {
    override SocketIOObject emitter;
    int firstDataIndex;

    SendNode() {
      exists(string m | this = emitter.ref().getAMethodCall(m) |
        // a call to `emit`
        m = "emit" and
        firstDataIndex = 1
        or
        // a call to `send` or `write`
        (m = "send" or m = "write") and
        firstDataIndex = 0
      )
    }

    /**
     * Gets the socket through which data is sent to the client.
     */
    SocketObject getSocket() { result = emitter }

    /**
     * Gets the namespace to which data is sent.
     */
    NamespaceObject getNamespace() { result = emitter.getNamespace() }

    /** Gets the event name associated with the data, if it can be determined. */
    override string getChannel() {
      if firstDataIndex = 1 then getArgument(0).mayHaveStringValue(result) else result = "message"
    }

    /** Gets the `i`th argument through which data is sent to the client. */
    override DataFlow::Node getSentItem(int i) {
      result = getArgument(i + firstDataIndex) and
      i >= 0 and
      (
        // exclude last argument if it looks like a callback
        result != getLastArgument() or not exists(SendCallback c | c.getSendNode() = this)
      )
    }

    /** Gets a client-side node that may be receiving the data sent here. */
    override SocketIOClient::ReceiveNode getAReceiver() {
      result.getSocket().getATargetNamespace() = getNamespace()
    }
  }

  /** A socket.io namespace, identified by its server and its path. */
  private newtype TNamespace =
    MkNamespace(ServerObject srv, string path) {
      path = "/"
      or
      srv.ref().getAMethodCall("of").getArgument(0).mayHaveStringValue(path)
    }

  /**
   * An acknowledgment callback registered when sending a message to a client.
   * Responses from clients are received using this callback.
   */
  class SendCallback extends EventRegistration::Range, DataFlow::FunctionNode {
    SendNode send;

    SendCallback() {
      // acknowledgments are only available when sending through a socket
      exists(send.getSocket()) and
      this = send.getLastArgument().getALocalSource() and
      emitter = send.getEmitter()
    }

    override string getChannel() { result = send.getChannel() }

    override DataFlow::Node getReceivedItem(int i) { result = this.getParameter(i) }

    /**
     * Gets the send node where this callback was registered.
     */
    SendNode getSendNode() { result = send }
  }

  /** A socket.io namespace. */
  class NamespaceObject extends TNamespace {
    ServerObject srv;
    string path;

    NamespaceObject() { this = MkNamespace(srv, path) }

    /** Gets the server to which this namespace belongs. */
    ServerObject getServer() { result = srv }

    /** Gets the path of this namespace. */
    string getPath() { result = path }

    /** Gets a textual representation of this namespace. */
    string toString() { result = "socket.io namespace with path '" + path + "'" }
  }
}

/**
 * Provides classes for working with client-side socket.io code
 * (npm package `socket.io-client`).
 */
module SocketIOClient {
  /** A socket object. */
  class SocketObject extends DataFlow::InvokeNode, EventEmitter::Range {
    SocketObject() {
      exists(DataFlow::SourceNode io |
        io = DataFlow::globalVarRef("io") or
        io = DataFlow::globalVarRef("io").getAPropertyRead("connect") or
        io = DataFlow::moduleImport("io") or
        io = DataFlow::moduleMember("io", "connect") or
        io = DataFlow::moduleImport("socket.io-client") or
        io = DataFlow::moduleMember("socket.io-client", "connect")
      |
        this = io.getAnInvocation()
      )
    }

    private DataFlow::SourceNode ref(DataFlow::TypeTracker t) {
      t.start() and result = this
      or
      exists(DataFlow::TypeTracker t2 | result = ref(t2).track(t2, t))
    }

    DataFlow::SourceNode ref() { result = ref(DataFlow::TypeTracker::end()) }

    /** Gets the path of the namespace this socket belongs to, if it can be determined. */
    string getNamespacePath() {
      // the path name of the specified URL
      exists(string url, string pathRegex |
        this.getArgument(0).mayHaveStringValue(url) and
        pathRegex = "(?<!/)/(?!/)[^?#]*"
      |
        result = url.regexpFind(pathRegex, 0, _)
        or
        // if the URL does not specify an explicit path, it defaults to "/"
        not exists(url.regexpFind(pathRegex, _, _)) and
        result = "/"
      )
      or
      // if no URL is specified, the path defaults to "/"
      not exists(this.getArgument(0)) and
      result = "/"
    }

    /**
     * Gets a server this socket may be communicating with.
     *
     * To avoid matching sockets with unrelated servers, we restrict the search to
     * servers defined in the same npm package. Furthermore, the server is required
     * to have a namespace with the same path as the namespace of this socket, if
     * it can be determined.
     */
    SocketIO::ServerObject getATargetServer() {
      getPackage(result) = getPackage(this) and
      (
        not exists(getNamespacePath()) or
        exists(result.getNamespace(getNamespacePath()))
      )
    }

    /** Gets a namespace this socket may be communicating with. */
    SocketIO::NamespaceObject getATargetNamespace() {
      result = getATargetServer().getNamespace(getNamespacePath())
      or
      // if the namespace of this socket cannot be determined, overapproximate
      not exists(getNamespacePath()) and
      result = getATargetServer().getNamespace(_)
    }

    /** Gets a server-side socket this client-side socket may be communicating with. */
    SocketIO::SocketObject getATargetSocket() { result.getNamespace() = getATargetNamespace() }
  }

  /** A data flow node that may produce a socket object. */
  class SocketNode extends DataFlow::SourceNode {
    SocketObject socket;

    SocketNode() { this = socket.ref() }

    /** Gets the path of the namespace this socket belongs to, if it can be determined. */
    string getNamespacePath() { result = socket.getNamespacePath() }

    /**
     * Gets a server this socket may be communicating with.
     *
     * To avoid matching sockets with unrelated servers, we restrict the search to
     * servers defined in the same npm package. Furthermore, the server is required
     * to have a namespace with the same path as the namespace of this socket, if
     * it can be determined.
     */
    SocketIO::ServerObject getATargetServer() { result = socket.getATargetServer() }

    /** Gets a namespace this socket may be communicating with. */
    SocketIO::NamespaceObject getATargetNamespace() { result = socket.getATargetNamespace() }

    /** Gets a server-side socket this client-side socket may be communicating with. */
    SocketIO::SocketNode getATargetSocket() { result.getNamespace() = socket.getATargetNamespace() }
  }

  /** Gets the NPM package that contains `nd`. */
  private NPMPackage getPackage(DataFlow::SourceNode nd) { result.getAFile() = nd.getFile() }

  /**
   * A data flow node representing an API call that receives data from the server.
   */
  class ReceiveNode extends DataFlow::MethodCallNode, EventRegistration::Range {
    override SocketObject emitter;

    ReceiveNode() { this = emitter.ref().getAMethodCall(EventEmitter::on()) }

    /** Gets the socket through which data is received. */
    SocketObject getSocket() { result = emitter }

    /** Gets the event name associated with the data, if it can be determined. */
    override string getChannel() { getArgument(0).mayHaveStringValue(result) }

    private DataFlow::SourceNode getListener(DataFlow::TypeBackTracker t) {
      t.start() and
      result = getArgument(1).getALocalSource()
      or
      exists(DataFlow::TypeBackTracker t2 | result = getListener(t2).backtrack(t2, t))
    }

    /** Gets the callback that handles data received from the server. */
    DataFlow::FunctionNode getListener() { result = getListener(DataFlow::TypeBackTracker::end()) }

    /** Gets the `i`th parameter through which data is received from the server. */
    override DataFlow::SourceNode getReceivedItem(int i) {
      exists(DataFlow::FunctionNode cb | cb = getListener() and result = cb.getParameter(i) |
        // exclude the last parameter if it looks like a callback
        result != cb.getLastParameter() or not exists(result.getAnInvocation())
      )
    }
  }

  /** An acknowledgment callback from a receive node. */
  class RecieveCallback extends EventDispatch::Range, DataFlow::SourceNode {
    override SocketObject emitter;
    ReceiveNode rcv;

    RecieveCallback() {
      this = rcv.getListener().getLastParameter() and
      exists(this.getAnInvocation()) and
      emitter = rcv.getEmitter()
    }

    override string getChannel() { result = rcv.getChannel() }

    override DataFlow::Node getSentItem(int i) { result = this.getACall().getArgument(i) }

    override SocketIO::SendCallback getAReceiver() { result.getSendNode().getAReceiver() = rcv }

    /**
     * Gets the receive node where this callback was registered.
     */
    ReceiveNode getReceiveNode() { result = rcv }
  }

  /**
   * A data flow node representing an API call that sends data to the server.
   */
  class SendNode extends DataFlow::MethodCallNode, EventDispatch::Range {
    override SocketObject emitter;
    int firstDataIndex;

    SendNode() {
      exists(string m | this = emitter.ref().getAMethodCall(m) |
        // a call to `emit`
        m = "emit" and
        firstDataIndex = 1
        or
        // a call to `send` or `write`
        (m = "send" or m = "write") and
        firstDataIndex = 0
      )
    }

    /**
     * Gets the socket through which data is sent to the server.
     */
    SocketObject getSocket() { result = emitter }

    /**
     * Gets the path of the namespace to which data is sent, if it can be determined.
     */
    string getNamespacePath() { result = emitter.getNamespacePath() }

    /** Gets the event name associated with the data, if it can be determined. */
    override string getChannel() {
      if firstDataIndex = 1 then getArgument(0).mayHaveStringValue(result) else result = "message"
    }

    /** Gets the `i`th argument through which data is sent to the server. */
    override DataFlow::Node getSentItem(int i) {
      result = getArgument(i + firstDataIndex) and
      i >= 0 and
      (
        // exclude last argument if it looks like a callback
        result != getLastArgument() or not exists(SendCallback c | c.getSendNode() = this)
      )
    }

    /** Gets a server-side node that may be receiving the data sent here. */
    override SocketIO::ReceiveNode getAReceiver() {
      result.getSocket().getNamespace() = getSocket().getATargetNamespace()
    }
  }

  /**
   * An acknowledgment callback registered when sending a message to a server.
   * Responses from servers are received using this callback.
   */
  class SendCallback extends EventRegistration::Range, DataFlow::FunctionNode {
    SendNode send;

    SendCallback() {
      this = send.getLastArgument().getALocalSource() and
      emitter = send.getEmitter()
    }

    override string getChannel() { result = send.getChannel() }

    override DataFlow::Node getReceivedItem(int i) { result = this.getParameter(i) }

    /**
     * Gets the SendNode where this callback was registered.
     */
    SendNode getSendNode() { result = send }
  }
}
