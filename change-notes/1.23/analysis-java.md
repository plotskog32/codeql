# Improvements to Java analysis

The following changes in version 1.23 affect Java analysis in all applications.

## Changes to existing queries

| **Query**                    | **Expected impact**    | **Change**                        |
|------------------------------|------------------------|-----------------------------------|
| Query built from user-controlled sources (`java/sql-injection`) | More results | The query now identifies arguments to `Statement.executeLargeUpdate` and `Connection.prepareCall` as SQL expressions sinks. |
| Query built from local-user-controlled sources (`java/sql-injection-local`) | More results | The query now identifies arguments to `Statement.executeLargeUpdate` and `Connection.prepareCall` as SQL expressions sinks. |
| Query built without neutralizing special characters (`java/concatenated-sql-query`) | More results | The query now identifies arguments to `Statement.executeLargeUpdate` and `Connection.prepareCall` as SQL expressions sinks. |

## Changes to QL libraries

* The data-flow library has been extended with a new feature to aid debugging.
  Instead of specifying `isSink(Node n) { any() }` on a configuration to
  explore the possible flow from a source, it is recommended to use the new
  `Configuration::hasPartialFlow` predicate, as this gives a more complete
  picture of the partial flow paths from a given source. The feature is
  disabled by default and can be enabled for individual configurations by
  overriding `int explorationLimit()`.
