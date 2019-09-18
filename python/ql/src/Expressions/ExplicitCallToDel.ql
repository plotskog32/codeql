/**
 * @name __del__ is called explicitly
 * @description The __del__ special method is called by the virtual machine when an object is being finalized. It should not be called explicitly.
 * @kind problem
 * @tags reliability
 *       correctness
 * @problem.severity warning
 * @sub-severity low
 * @precision very-high
 * @id py/explicit-call-to-delete
 */

import python

class DelCall extends Call {
  DelCall() {
    ((Attribute)this.getFunc()).getName() = "__del__"
  }
  
  predicate isSuperCall() {
    exists(Function f | f = this.getScope() and f.getName() = "__del__" |
      // We pass in `self` as the first argument...
      f.getArg(0).asName().getVariable() = ((Name)this.getArg(0)).getVariable() or
      // ... or the call is of the form `super(Type, self).__del__()`, or the equivalent
      // Python 3: `super().__del__()`.
      exists(Call superCall | superCall = ((Attribute)this.getFunc()).getObject() |
        ((Name)superCall.getFunc()).getId() = "super"
      )
    )
  }
}

from DelCall del
where not del.isSuperCall()
select del, "The __del__ special method is called explicitly."