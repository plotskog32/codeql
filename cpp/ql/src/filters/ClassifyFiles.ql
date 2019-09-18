/**
 * @name Classify files
 * @description This query produces a list of all files in a snapshot
 *              that are classified as generated code or test code.
 * @kind file-classifier
 * @id cpp/file-classifier
 */

import cpp
import semmle.code.cpp.AutogeneratedFile
import semmle.code.cpp.TestFile

predicate classify(File f, string tag) {
  f instanceof AutogeneratedFile and
  tag = "generated"
  or
  f instanceof TestFile and
  tag = "test"
}

from File f, string tag
where classify(f, tag)
select f, tag
