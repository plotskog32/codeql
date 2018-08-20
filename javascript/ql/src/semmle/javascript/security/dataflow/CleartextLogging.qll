/**
 * Provides a dataflow tracking configuration for reasoning about clear-text logging of sensitive information.
 */
import javascript
private import semmle.javascript.dataflow.InferredTypes
private import semmle.javascript.security.SensitiveActions::HeuristicNames

module CleartextLogging {
  /**
   * A data flow source for clear-text logging of sensitive information.
   */
  abstract class Source extends DataFlow::Node {
    /** Gets a string that describes the type of this data flow source. */
    abstract string describe();
  }

  /**
   * A data flow sink for clear-text logging of sensitive information.
   */
  abstract class Sink extends DataFlow::Node { }

  /**
   * A barrier for clear-text logging of sensitive information.
   */
  abstract class Barrier extends DataFlow::Node { }

  /**
   * A dataflow tracking configuration for clear-text logging of sensitive information.
   *
   * This configuration identifies flows from `Source`s, which are sources of
   * sensitive data, to `Sink`s, which is an abstract class representing all
   * the places sensitive data may be stored in clear-text. Additional sources or sinks can be
   * added either by extending the relevant class, or by subclassing this configuration itself,
   * and amending the sources and sinks.
   */
  class Configuration extends DataFlow::Configuration {
    Configuration() { this = "CleartextLogging" }

    override
    predicate isSource(DataFlow::Node source) {
      source instanceof Source
    }

    override
    predicate isSink(DataFlow::Node sink) {
      sink instanceof Sink
    }

    override
    predicate isBarrier(DataFlow::Node node) {
      node instanceof Barrier
    }

    override predicate isAdditionalFlowStep(DataFlow::Node src, DataFlow::Node trg) {
      // A taint propagating data flow edge arising from string operations
      exists (AST::ValueNode astNode |
        astNode = trg.(DataFlow::ValueNode).getAstNode() |
        // addition propagates
        astNode.(AddExpr).getAnOperand() = src.asExpr() or
        astNode.(AssignAddExpr).getAChildExpr() = src.asExpr() or
        exists (SsaExplicitDefinition ssa |
          astNode = ssa.getVariable().getAUse() and
          src.asExpr().(AssignAddExpr) = ssa.getDef()
        )
        or
        // templating propagates
        astNode.(TemplateLiteral).getAnElement() = src.asExpr()
        or
        // other string operations that propagate
        exists (string name | name = astNode.(MethodCallExpr).getMethodName() |
          src.asExpr() = astNode.(MethodCallExpr).getReceiver() and
          (
            // sorted, interesting, properties of Object.prototype
            name = "toString" or
            name = "valueOf"
          )
        )
      )
      or
      // A taint propagating data flow edge through objects: a tainted write taints the entire object.
      exists (DataFlow::PropWrite write |
        write.getRhs() = src and
        trg.(DataFlow::SourceNode).flowsTo(write.getBase())
      )
    }
  }

  /**
   * An argument to a logging mechanism.
   */
  class LoggerSink extends Sink {
    LoggerSink() {
      this = any(LoggerCall log).getAMessageComponent()
    }
  }

  /**
   * A data flow node that does not contain a clear-text password, according to its syntactic name.
   */
  private class NameGuidedNonCleartextPassword extends NonCleartextPassword {

    NameGuidedNonCleartextPassword() {
      exists (string name |
        name.regexpMatch(nonSuspicious()) |
        this.asExpr().(VarAccess).getName() = name
        or
        this.(DataFlow::PropRead).getPropertyName() = name
        or
        this.(DataFlow::InvokeNode).getCalleeName() = name
      )
      or
      // avoid i18n strings
      this.(DataFlow::PropRead).getBase().asExpr().(VarRef).getName().regexpMatch("(?is).*(messages|strings).*")
    }

  }

  /**
   * A data flow node that is definitely not an object.
   */
  private class NonObject extends NonCleartextPassword {

    NonObject() {
      forall (AbstractValue v | v = analyze().getAValue() |
        not v.getType() = TTObject()
      )
    }

  }

  /**
   * A data flow node that receives flow that is not a clear-text password.
   */
  private class NonCleartextPasswordFlow extends NonCleartextPassword {

    NonCleartextPasswordFlow() {
      any(NonCleartextPassword other).(DataFlow::SourceNode).flowsTo(this)
    }

  }

  /**
   * A call that might obfuscate a password, for example through hashing.
   */
  private class ObfuscatorCall extends Barrier, DataFlow::InvokeNode {

    ObfuscatorCall() {
      getCalleeName().regexpMatch(nonSuspicious())
    }

  }

  /**
   * A data flow node that does not contain a clear-text password.
   */
  private abstract class NonCleartextPassword extends DataFlow::Node { }

  /**
   * An object with a property that may contain password information
   *
   * This is a source since `console.log(obj)` will show the properties of `obj`.
   */
  private class ObjectPasswordPropertySource extends DataFlow::ValueNode, Source {
    string name;

    ObjectPasswordPropertySource() {
      exists (DataFlow::PropWrite write |
        name.regexpMatch(suspiciousPassword()) and
        not name.regexpMatch(nonSuspicious()) and
        write = this.(DataFlow::SourceNode).getAPropertyWrite(name) and
        // avoid safe values assigned to presumably unsafe names
        not write.getRhs() instanceof NonCleartextPassword
      )
    }

    override string describe() {
      result = "an access to " + name
    }
  }

  /** An access to a variable or property that might contain a password. */
  private class ReadPasswordSource extends DataFlow::ValueNode, Source {
    string name;

    ReadPasswordSource() {
      // avoid safe values assigned to presumably unsafe names
      not this instanceof NonCleartextPassword and
      name.regexpMatch(suspiciousPassword()) and
      (
        this.asExpr().(VarAccess).getName() = name
        or
        exists (DataFlow::SourceNode base |
          this = base.getAPropertyRead(name) and
          // avoid safe values assigned to presumably unsafe names
          exists (DataFlow::SourceNode baseObj | baseObj.flowsTo(base) |
            not base.getAPropertyWrite(name).getRhs() instanceof NonCleartextPassword
          )
        )
      )
    }

    override string describe() {
      result = "an access to " + name
    }
  }

  /** A call that might return a password. */
  private class CallPasswordSource extends DataFlow::ValueNode, DataFlow::InvokeNode, Source {
    string name;

    CallPasswordSource() {
      name = getCalleeName() and
      name.regexpMatch("(?is)getPassword")
    }

    override string describe() {
      result = "a call to " + name
    }
  }

}