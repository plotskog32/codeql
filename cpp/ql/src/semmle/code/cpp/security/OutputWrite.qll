/**
 * Provides classes for modelling output to standard output / standard error through various mechanisms such as `printf`, `puts` and `operator<<`.
 */

import cpp
import FileWrite

/**
 * A function call that writes to standard output or standard error.
 */
class OutputWrite extends Expr {
  OutputWrite() { outputWrite(this, _) }

  /**
   * Gets a source expression for this output.
   */
  Expr getASource() { outputWrite(this, result) }
}

/**
 * A standard output or standard error variable.
 */
private predicate outputVariable(Variable v) {
  // standard output
  v.hasName("cout") or
  v.hasName("wcout") or
  // standard error
  v.hasName("cerr") or
  v.hasName("clog") or
  v.hasName("wcerr") or
  v.hasName("wclog")
}

/**
 * An expr representing standard output or standard error.
 */
private predicate outputExpr(ChainedOutputCall out) {
  // output chain ending in an access to standard output / standard error
  outputVariable(out.getEndDest().(VariableAccess).getTarget())
}

/**
 * A file representing standard output or standard error.
 */
private predicate outputFile(Expr e) {
  exists(string name |
    (
      name = e.(VariableAccess).getTarget().(GlobalVariable).toString() or
      name = e.findRootCause().(Macro).getName()
    ) and
    (
      name = "stdout" or
      name = "stderr"
    )
  )
}

/**
 * Holds if the function call is a write to standard output or standard error from 'source'.
 */
private predicate outputWrite(Expr write, Expr source) {
  exists(Function f, int arg |
    f = write.(Call).getTarget() and source = write.(Call).getArgument(arg)
  |
    // printf
    arg >= f.(Printf).getFormatParameterIndex()
    or
    // syslog
    arg >= f.(Syslog).getFormatParameterIndex()
    or
    // puts, putchar
    (
      f.hasGlobalOrStdName("puts") or
      f.hasGlobalOrStdName("putchar")
    ) and
    arg = 0
    or
    exists(Call wrappedCall, Expr wrappedSource |
      // wrapped output call (recursive case)
      outputWrite(wrappedCall, wrappedSource) and
      wrappedCall.getEnclosingFunction() = f and
      parameterUsePair(f.getParameter(arg), wrappedSource)
    )
  )
  or
  // output to standard output / standard error using operator<<, put or write
  outputExpr(write) and
  source = write.(ChainedOutputCall).getSource()
  or
  exists(FileWrite fileWrite |
    // output to stdout, stderr as a file (using FileWrite.qll logic)
    write = fileWrite and
    outputFile(fileWrite.getDest()) and
    source = fileWrite.getASource()
  )
}
