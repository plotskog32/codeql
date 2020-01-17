/**
 * Provides default sources, sinks and sanitizers for reasoning about
 * unsafe jQuery plugins, as well as extension points for adding your
 * own.
 */

import javascript
private import semmle.javascript.dataflow.InferredTypes
import semmle.javascript.security.dataflow.Xss

module UnsafeJQueryPlugin {
  private import DataFlow::FlowLabel

  /**
   * A data flow source for unsafe jQuery plugins.
   */
  abstract class Source extends DataFlow::Node {
    /**
     * Gets the plugin that this source is used in.
     */
    abstract JQueryPluginMethod getPlugin();
  }

  /**
   * A data flow sink for unsafe jQuery plugins.
   */
  abstract class Sink extends DataFlow::Node { }

  /**
   * A sanitizer for unsafe jQuery plugins.
   */
  abstract class Sanitizer extends DataFlow::Node { }

  /**
   * An argument that may act as a HTML fragment rather than a CSS selector, as a sink for remote unsafe jQuery plugins.
   */
  class AmbiguousHtmlOrSelectorArgument extends DataFlow::Node {
    AmbiguousHtmlOrSelectorArgument() {
      exists(JQuery::MethodCall call |
        call.interpretsArgumentAsSelector(this) and call.interpretsArgumentAsHtml(this)
      ) and
      // the $-function in particular will not construct HTML for non-string values
      analyze().getAType() = TTString() and
      // any fixed prefix makes the call unambiguous
      not exists(DataFlow::Node prefix |
        DomBasedXss::isPrefixOfJQueryHtmlString(this, prefix) and
        prefix.mayHaveStringValue(_)
      )
    }
  }

  /**
   * Holds for jQuery plugin definitions of the form `$.fn.<pluginName> = <plugin>`.
   */
  private predicate jQueryPluginDefinition(string pluginName, DataFlow::Node plugin) {
    exists(DataFlow::PropRead fn, DataFlow::PropWrite write |
      fn = jquery().getAPropertyRead("fn") and
      (
        write = fn.getAPropertyWrite()
        or
        exists(ExtendCall extend, DataFlow::SourceNode source |
          fn.flowsTo(extend.getDestinationOperand()) and
          source = extend.getASourceOperand() and
          write = source.getAPropertyWrite()
        )
      ) and
      plugin = write.getRhs() and
      (
        pluginName = write.getPropertyName() or
        write.getPropertyNameExpr().flow().mayHaveStringValue(pluginName)
      )
    )
  }

  /**
   * Gets an function that is registered as a jQuery plugin method at `def`.
   */
  private DataFlow::FunctionNode getAJQueryPluginMethod(
    DataFlow::TypeBackTracker t, DataFlow::Node def
  ) {
    t.start() and
    jQueryPluginDefinition(_, def) and
    result.flowsTo(def)
    or
    exists(DataFlow::TypeBackTracker t2 | result = getAJQueryPluginMethod(t2, def).backtrack(t2, t))
  }

  /**
   * Gets an operand to `extend`.
   */
  private DataFlow::SourceNode getAnExtendOperand(DataFlow::TypeBackTracker t, ExtendCall extend) {
    t.start() and
    result.flowsTo(extend.getAnOperand())
    or
    exists(DataFlow::TypeBackTracker t2 | result = getAnExtendOperand(t2, extend).backtrack(t2, t))
  }

  /**
   * A function that is registered as a jQuery plugin method.
   */
  class JQueryPluginMethod extends DataFlow::FunctionNode {
    string pluginName;

    JQueryPluginMethod() {
      exists(DataFlow::Node def |
        jQueryPluginDefinition(pluginName, def) and
        this = getAJQueryPluginMethod(DataFlow::TypeBackTracker::end(), def)
      )
    }

    /**
     * Gets the name of this plugin.
     */
    string getPluginName() { result = pluginName }
  }

  /**
   * Holds if `plugin` has a default option defined a `def`.
   */
  private predicate hasDefaultOption(JQueryPluginMethod plugin, DataFlow::PropWrite def) {
    exists(ExtendCall extend, JQueryPluginOptions options, DataFlow::SourceNode default |
      options.getPlugin() = plugin and
      options = getAnExtendOperand(DataFlow::TypeBackTracker::end(), extend) and
      default = getAnExtendOperand(DataFlow::TypeBackTracker::end(), extend) and
      default.getAPropertyWrite() = def
    )
  }

  /**
   * The client-provided options object for a jQuery plugin.
   */
  class JQueryPluginOptions extends DataFlow::ParameterNode {
    JQueryPluginMethod method;

    JQueryPluginOptions() {
      exists(string optionsPattern |
        optionsPattern = "(?i)(opt(ion)?s?)" and
        if method.getAParameter().getName().regexpMatch(optionsPattern)
        then (
          // use the last parameter named something like "options" if it exists ...
          getName().regexpMatch(optionsPattern) and
          this = method.getAParameter()
        ) else (
          // ... otherwise, use the last parameter, unless it looks like a DOM node
          this = method.getLastParameter() and
          not getName().regexpMatch("(?i)(e(l(em(ent(s)?)?)?)?)")
        )
      )
    }

    /**
     * Gets the plugin method that these options are used in.
     */
    JQueryPluginMethod getPlugin() { result = method }
  }

  /**
   * Expression of form `isElement(x)`, which sanitizes `x`.
   */
  class IsElementSanitizer extends TaintTracking::SanitizerGuardNode, DataFlow::CallNode {
    IsElementSanitizer() {
      // common ad hoc sanitizing calls
      exists(string name | getCalleeName() = name |
        name = "isElement" or name = "isWindow" or name = "isWindow"
      )
    }

    override predicate sanitizes(boolean outcome, Expr e) {
      outcome = true and e = getArgument(0).asExpr()
    }
  }

  /**
   * Expression of form `typeof x.jquery !== "undefined"` or `x.jquery`, which sanitizes `x`.
   */
  class IsJQueryObjectSanitizer extends TaintTracking::SanitizerGuardNode, DataFlow::ValueNode {
    DataFlow::Node input;
    boolean polarity;

    IsJQueryObjectSanitizer() {
      exists(DataFlow::PropRead read | read.accesses(input, "jquery") |
        exists(EqualityTest test |
          polarity = test.getPolarity().booleanNot() and
          this = test.flow()
        |
          exists(Expr undef | test.hasOperands(read.asExpr(), undef) |
            SyntacticConstants::isUndefined(undef)
          )
          or
          exists(Expr op1, Expr op2 | test.hasOperands(op1, op2) |
            read.asExpr() = op1.(TypeofExpr).getOperand() and
            op2.mayHaveStringValue(any(InferredType t | t = TTUndefined()).getTypeofTag())
          )
        )
        or
        polarity = true and
        this = read
      )
    }

    override predicate sanitizes(boolean outcome, Expr e) {
      outcome = polarity and
      e = input.asExpr()
    }
  }

  /**
   * The client-provided options object for a jQuery plugin, considered as a source for unsafe jQuery plugins.
   */
  class JQueryPluginOptionsAsSource extends Source, JQueryPluginOptions {
    override JQueryPluginMethod getPlugin() { result = JQueryPluginOptions.super.getPlugin() }
  }

  /**
   * An argument that may act as a HTML fragment rather than a CSS selector, as a sink for remote unsafe jQuery plugins.
   */
  class AmbiguousHtmlOrSelectorArgumentAsSink extends Sink {
    AmbiguousHtmlOrSelectorArgumentAsSink() { this instanceof AmbiguousHtmlOrSelectorArgument }
  }

  /**
   * A hint that a value is expected to be treated as a HTML fragment later.
   */
  class IntentionalHtmlFragmentHint extends Sanitizer {
    IntentionalHtmlFragmentHint() {
      this.(DataFlow::PropRead).getPropertyName().regexpMatch("(?i).*(html|template).*")
    }
  }

  /**
   * Holds if `plugin` likely expects `sink` to be treated as a HTML fragment.
   */
  predicate isLikelyIntentionalHtmlSink(JQueryPluginMethod plugin, Sink sink) {
    exists(DataFlow::PropWrite defaultDef, string default, DataFlow::PropRead finalRead |
      hasDefaultOption(plugin, defaultDef) and
      defaultDef.getPropertyName() = finalRead.getPropertyName() and
      defaultDef.getRhs().mayHaveStringValue(default) and
      default.regexpMatch("\\s*<.*") and
      finalRead.flowsTo(sink)
    )
  }
}
