/**
 * Definitions related to `java.net.*`.
 */

import semmle.code.java.Type

/** The type `java.net.URLConnection`. */
class TypeUrlConnection extends RefType {
  TypeUrlConnection() { hasQualifiedName("java.net", "URLConnection") }
}

/** The type `java.net.Socket`. */
class TypeSocket extends RefType {
  TypeSocket() { hasQualifiedName("java.net", "Socket") }
}

/** The type `java.net.URL`. */
class TypeUrl extends RefType {
  TypeUrl() { hasQualifiedName("java.net", "URL") }
}

/** The type `java.net.URI`. */
class TypeUri extends RefType {
  TypeUri() { hasQualifiedName("java.net", "URI") }
}

/** The method `java.net.URLConnection::getInputStream`. */
class URLConnectionGetInputStreamMethod extends Method {
  URLConnectionGetInputStreamMethod() {
    getDeclaringType() instanceof TypeUrlConnection and
    hasName("getInputStream") and
    hasNoParameters()
  }
}

/** The method `java.net.Socket::getInputStream`. */
class SocketGetInputStreamMethod extends Method {
  SocketGetInputStreamMethod() {
    getDeclaringType() instanceof TypeSocket and
    hasName("getInputStream") and
    hasNoParameters()
  }
}

/** A method or constructor call that returns a new `URI`. */
class UriCreation extends Call {
  UriCreation() {
    this.getCallee().getDeclaringType() instanceof TypeUri and
    (this instanceof ClassInstanceExpr or this.getCallee().hasName("create"))
  }

  /**
   * Gets the host argument of the newly created URI. In the case where the
   * host is specified separately, this is only the host. In the case where the
   * uri is parsed from an input string, such as in
   * `URI("http://foo.com/mypath")`, this is the entire argument passed in,
   * that is `"http://foo.com/mypath"`.
   */
  Expr getHostArg() { none() }
}

/** A `java.net.URI` constructor call. */
class UriConstructorCall extends ClassInstanceExpr, UriCreation {
  override Expr getHostArg() {
    // URI(String str)
    result = this.getArgument(0) and this.getNumArgument() = 1
    or
    // URI(String scheme, String ssp, String fragment)
    // URI(String scheme, String host, String path, String fragment)
    // URI(String scheme, String authority, String path, String query, String fragment)
    result = this.getArgument(1) and this.getNumArgument() = [3, 4, 5]
    or
    // URI(String scheme, String userInfo, String host, int port, String path, String query,
    //    String fragment)
    result = this.getArgument(2) and this.getNumArgument() = 7
  }
}

/** A call to `java.net.URI::create`. */
class UriCreate extends UriCreation {
  UriCreate() { this.getCallee().hasName("create") }

  override Expr getHostArg() { result = this.getArgument(0) }
}

/** A `java.net.URL` constructor call. */
class UrlConstructorCall extends ClassInstanceExpr {
  UrlConstructorCall() { this.getConstructor().getDeclaringType() instanceof TypeUrl }

  /** Gets the host argument of the newly created URL. */
  Expr getHostArg() {
    // URL(String spec)
    this.getNumArgument() = 1 and result = this.getArgument(0)
    or
    // URL(String protocol, String host, int port, String file)
    // URL(String protocol, String host, int port, String file, URLStreamHandler handler)
    this.getNumArgument() = [4, 5] and result = this.getArgument(1)
    or
    // URL(String protocol, String host, String file)
    // but not
    // URL(URL context, String spec, URLStreamHandler handler)
    this.getNumArgument() = 3 and
    this.getConstructor().getParameterType(2) instanceof TypeString and
    result = this.getArgument(1)
  }

  /** Gets the argument that corresponds to the protocol of the URL. */
  Expr protocolArg() {
    // In all cases except where the first parameter is a URL, the argument
    // containing the protocol is the first one, otherwise it is the second.
    if this.getConstructor().getParameterType(0) instanceof TypeUrl
    then result = this.getArgument(1)
    else result = this.getArgument(0)
  }
}

/** The method `java.net.URL::openStream`. */
class UrlOpenStreamMethod extends Method {
  UrlOpenStreamMethod() {
    this.getDeclaringType() instanceof TypeUrl and
    this.getName() = "openStream"
  }
}

/** The method `java.net.URL::openConnection`. */
class UrlOpenConnectionMethod extends Method {
  UrlOpenConnectionMethod() {
    this.getDeclaringType() instanceof TypeUrl and
    this.getName() = "openConnection"
  }
}
