/**
 * Provides classes and predicates for working with the Apache Thrift framework.
 */

import java

/**
 * A file detected as generated by the Apache Thrift Compiler.
 */
class ThriftGeneratedFile extends GeneratedFile {
  ThriftGeneratedFile() {
    exists(JavadocElement t | t.getFile() = this |
      exists(string msg | msg = t.getText() | msg.regexpMatch("(?i).*\\bAutogenerated by Thrift.*"))
    )
  }
}

/**
 * A Thrift `Iface` interface in a class generated by the Apache Thrift Compiler.
 */
class ThriftIface extends Interface {
  ThriftIface() {
    this.hasName("Iface") and
    this.getEnclosingType() instanceof TopLevelType and
    this.getFile() instanceof ThriftGeneratedFile
  }

  Method getAnImplementingMethod() {
    result.getDeclaringType().(Class).getASupertype+() = this and
    result.overrides(getAMethod()) and
    not result.getFile() = this.getFile()
  }
}
