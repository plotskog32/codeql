/**
 * Provides a class for modeling external functions that are "safe" from a security perspective.
 */

private import cpp
private import semmle.code.cpp.models.implementations.Pure

/**
 * A `Function` that is considered a "safe" external API from a security perspective.
 */
abstract class SafeExternalAPIFunction extends Function { }

/** The default set of "safe" external APIs. */
private class DefaultSafeExternalAPIFunction extends SafeExternalAPIFunction {
  DefaultSafeExternalAPIFunction() {
    // implementation note: this should be based on the properties of public interfaces, rather than accessing implementation classes directly.  When we've done that, the three classes referenced here should be made fully private.
    this instanceof PureStrFunction or
    this instanceof StrLenFunction or
    this instanceof PureMemFunction
  }
}
