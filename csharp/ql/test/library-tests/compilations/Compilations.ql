import csharp
import semmle.code.csharp.commons.Diagnostics

query predicate diagnostics(
  Diagnostic d, string tag, int severity, string message, string fullMessage
) {
  tag = d.getTag() and
  severity = d.getSeverity() and
  message = d.getMessage() and
  fullMessage = d.getFullMessage()
}

query predicate compilationErrors(CompilerError e) { any() }

query predicate metricIsZero(Compilation compilation, int metric) {
  compilation.getMetric(metric) = 0 and
  metric != 6 // Peak working set not implemented on Linux
}

query predicate compilation(Compilation c, string f) { f = c.getDirectoryString() }

query predicate compilationArguments(Compilation compilation, int i, string arg) {
  arg = compilation.getArgument(i)
}

query predicate compilationFiles(Compilation compilation, int i, File f) {
  f = compilation.getFileCompiled(i)
}

query predicate compilationFolder(Compilation c, string folder) {
  folder = c.getFolder().getBaseName()
}

query predicate diagnosticElements(Diagnostic d, Element e) { e = d.getElement() }
