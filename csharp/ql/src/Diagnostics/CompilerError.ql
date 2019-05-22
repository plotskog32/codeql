/**
 * @name Compilation error
 * @description A compilation error can cause extraction problems, and could lead to inaccurate results.
 * @kind problem
 * @problem.severity recommendation
 * @precision medium
 * @id cs/compilation-error
 * @tags internal
 */

import csharp
import semmle.code.csharp.commons.Diagnostics

from CompilerError diagnostic
select diagnostic,
  diagnostic.getSeverityText() + " " + diagnostic.getTag() + " " + diagnostic.getFullMessage()
