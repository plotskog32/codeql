/**
 * @name Number of file re-commits
 * @description A re-commit is taken to mean a commit to a file that was touched less than five days ago.
 * @kind treemap
 * @treemap.warnOn highValues
 * @metricType file
 * @metricAggregate avg min max
 * @id cs/vcs/recommits-per-file
 */
import csharp
import external.VCS

predicate inRange(Commit first, Commit second) {
  first.getAnAffectedFile() = second.getAnAffectedFile() and
  first != second and
  exists(int n | n = first.getDate().daysTo(second.getDate()) and
    n >= 0 and n < 5)
}

int recommitsForFile(File f) {
  result = count(Commit recommit |
    f = recommit.getAnAffectedFile() and
    exists(Commit prev | inRange(prev, recommit)))
}

from File f
where f.getExtension() = "c"
select f, recommitsForFile(f)

