/**
 * Provides classes for working with JSON data.
 */

import javascript

/**
 * A JSON-encoded value, which may be a primitive value, an array or an object.
 */
class JSONValue extends @json_value, Locatable {
  override Location getLocation() { json_locations(this, result) }

  /** Gets the parent value to which this value belongs, if any. */
  JSONValue getParent() { json(this, _, result, _, _) }

  /** Gets the `i`th child value of this value. */
  JSONValue getChild(int i) { json(result, _, this, i, _) }

  /** Holds if this JSON value is the top level element in its enclosing file. */
  predicate isTopLevel() { not exists(getParent()) }

  override string toString() { json(this, _, _, _, result) }
}

/**
 * A JSON-encoded primitive value.
 */
abstract class JSONPrimitiveValue extends JSONValue {
  /** Gets a string representation of the encoded value. */
  string getValue() { json_literals(result, _, this) }

  /** Gets the source text of the encoded value; for strings, this includes quotes. */
  string getRawValue() { json_literals(_, result, this) }
}

/**
 * A JSON-encoded null value.
 */
class JSONNull extends @json_null, JSONPrimitiveValue { }

/**
 * A JSON-encoded Boolean value.
 */
class JSONBoolean extends @json_boolean, JSONPrimitiveValue { }

/**
 * A JSON-encoded number.
 */
class JSONNumber extends @json_number, JSONPrimitiveValue { }

/**
 * A JSON-encoded string value.
 */
class JSONString extends @json_string, JSONPrimitiveValue { }

/**
 * A JSON-encoded array.
 */
class JSONArray extends @json_array, JSONValue {
  /** Gets the value of the `i`th element of this array. */
  JSONValue getElementValue(int i) { result = getChild(i) }

  /** Gets the string value of the `i`th element of this array. */
  string getElementStringValue(int i) { result = getElementValue(i).(JSONString).getValue() }
}

/**
 * A JSON-encoded object.
 */
class JSONObject extends @json_object, JSONValue {
  /** Gets the value of property `name` of this object. */
  JSONValue getPropValue(string name) { json_properties(this, name, result) }

  /** Gets the string value of property `name` of this object. */
  string getPropStringValue(string name) { result = getPropValue(name).(JSONString).getValue() }
}

/**
 * An error reported by the JSON parser.
 */
class JSONParseError extends @json_parse_error, Error {
  override Location getLocation() { json_locations(this, result) }

  override string getMessage() { json_errors(this, result) }
}
