/**
 * Provides the .Net `Element` class.
 */
private import DotNet
import semmle.code.csharp.Location

/**
 * A .Net program element.
 */
class Element extends @dotnet_element {
  /** Gets a textual representation of this element. */
  string toString() { none() }

  /** Gets the location of this element. */
  Location getLocation() { none() }

 /**
  * Gets a location of this element, which can include locations in
  * both DLLs and source files.
  */
  Location getALocation() { none() }

  /** Gets the file containing this element. */
  File getFile() { result = getLocation().getFile() }

  /** Holds if this element is from source code. */
  predicate fromSource() { none() }

  /**
   * Gets the "language" of this program element, as defined by the extension of the filename.
   * For example, C# has language "cs", and Visual Basic has language "vb".
   */
  final string getLanguage() { result = getLocation().getFile().getExtension() }

  /** Gets the full textual representation of this element, including type information. */
  string toStringWithTypes() { result = this.toString() }
}

/** An element that has a name. */
class NamedElement extends Element, @dotnet_named_element {
  /** Gets the name of this element. */
  string getName() { none() }

  /** Holds if this element has name 'name'. */
  final predicate hasName(string name) { name = getName() }

  /**
   * Gets the fully qualified name of this element, for example the
   * fully qualified name of `M` on line 3 is `N.C.M` in
   *
   * ```
   * namespace N {
   *   class C {
   *     void M(int i, string s) { }
   *   }
   * }
   * ```
   */
  final string getQualifiedName() {
    exists(string qualifier, string name |
      this.hasQualifiedName(qualifier, name) |
      if qualifier = "" then
        result = name
      else
        result = qualifier + "." + name
    )
  }

  /**
   * Holds if this element has qualified name `qualifiedName`, for example
   * `System.Console.WriteLine`.
   */
  final predicate hasQualifiedName(string qualifiedName) {
    qualifiedName = this.getQualifiedName()
  }

  /** Holds if this element has the qualified name `qualifier`.`name`. */
  predicate hasQualifiedName(string qualifier, string name) {
    qualifier = "" and name = this.getName()
  }

  /** Gets a unique string label for this element. */
  string getLabel() { none() }

  /**
   * Holds if this element was compiled from source code that is also present in the
   * database. That is, this element corresponds to another element from source.
   */
  predicate compiledFromSource() {
    not this.fromSource()
    and
    exists(NamedElement other |
      other != this |
      other.getLabel() = this.getLabel() and
      other.fromSource()
    )
  }

  override string toString() { result = this.getName() }
}
