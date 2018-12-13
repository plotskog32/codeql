/**
 * @name Dereferenced variable may be null
 * @description Dereferencing a variable whose value may be 'null' may cause a
 *              'NullReferenceException'.
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @id cs/dereferenced-value-may-be-null
 * @tags reliability
 *       correctness
 *       exceptions
 *       external/cwe/cwe-476
 */

import csharp
import semmle.code.csharp.dataflow.Nullness

from Dereference d, Ssa::SourceVariable v, string msg, Element reason
where d.isFirstMaybeNull(v.getAnSsaDefinition(), msg, reason)
select d, "Variable $@ may be null here " + msg + ".", v, v.toString(), reason, "this"
