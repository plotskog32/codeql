/**
 * Provides classes for reasoning about type annotations independently of dialect.
 */

import javascript 

/**
 * A type annotation, either in the form of a TypeScript type or a JSDoc comment.
 */
class TypeAnnotation extends @type_annotation {
  /** Gets a string representation of this type. */
  string toString() { none() }

  /** Holds if this is the `any` type. */
  predicate isAny() { none() }

  /** Holds if this is the `string` type. Does not hold for the (rarely used) `String` type. */
  predicate isString() { none() }

  /** Holds if this is the `string` or `String` type. */
  predicate isStringy() { none() }

  /** Holds if this is the `number` type. Does not hold for the (rarely used) `Number` type. */
  predicate isNumber() { none() }

  /** Holds if this is the `number` or `Number`s type. */
  predicate isNumbery() { none() }

  /** Holds if this is the `boolean` type. Does not hold for the (rarely used) `Boolean` type. */
  predicate isBoolean() { none() }

  /** Holds if this is the `boolean` or `Boolean` type. */
  predicate isBooleany() { none() }

  /** Holds if this is the `undefined` type. */
  predicate isUndefined() { none() }

  /** Holds if this is the `null` type. */
  predicate isNull() { none() }

  /** Holds if this is the `void` type. */
  predicate isVoid() { none() }

  /** Holds if this is the `never` type, or an equivalent type representing the empty set of values. */
  predicate isNever() { none() }

  /** Holds if this is the `this` type. */
  predicate isThis() { none() }

  /** Holds if this is the `symbol` type. */
  predicate isSymbol() { none() }

  /** Holds if this is the `unique symbol` type. */
  predicate isUniqueSymbol() { none() }

  /** Holds if this is the `Function` type. */
  predicate isRawFunction() { none() }

  /** Holds if this is the `object` type. */
  predicate isObjectKeyword() { none() }

  /** Holds if this is the `unknown` type. */
  predicate isUnknownKeyword() { none() }

  /** Holds if this is the `bigint` type. */
  predicate isBigInt() { none() }

  /** Holds if this is the `const` keyword, occurring in a type assertion such as `x as const`. */
  predicate isConstKeyword() { none() }
}
