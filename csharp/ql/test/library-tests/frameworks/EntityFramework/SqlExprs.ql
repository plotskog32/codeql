import csharp
import semmle.code.csharp.frameworks.Sql

from SqlExpr expr
select expr, expr.(Call).getTarget().getQualifiedName()