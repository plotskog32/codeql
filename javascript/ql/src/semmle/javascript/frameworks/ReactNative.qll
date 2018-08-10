/**
 * Provides classes for working with [React Native](https://facebook.github.io/react-native) code.
 */

import javascript

module ReactNative {
  /** A `WebView` JSX element. */
  class WebViewElement extends DataFlow::ValueNode, DataFlow::DefaultSourceNode {
    override JSXElement astNode;

    WebViewElement() {
      DataFlow::moduleMember("react-native", "WebView").flowsToExpr(astNode.getNameExpr())
    }
  }
}
