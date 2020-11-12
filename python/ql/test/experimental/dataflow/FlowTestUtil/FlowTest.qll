import python
import semmle.python.dataflow.new.DataFlow
import TestUtilities.InlineExpectationsTest

abstract class FlowTest extends InlineExpectationsTest {
  bindingset[this]
  FlowTest() { any() }

  abstract string flowTag();

  abstract predicate relevantFlow(DataFlow::Node fromNode, DataFlow::Node toNode);

  override string getARelevantTag() { result = this.flowTag() }

  override predicate hasActualResult(Location location, string element, string tag, string value) {
    exists(DataFlow::Node fromNode, DataFlow::Node toNode | this.relevantFlow(fromNode, toNode) |
      location = toNode.getLocation() and
      tag = this.flowTag() and
      value =
        "\"" + fromNode.toString() + lineStr(fromNode, toNode) + " -> " + toNode.toString() + "\"" and
      element = toNode.toString()
    )
  }

  pragma[inline]
  private string lineStr(DataFlow::Node fromNode, DataFlow::Node toNode) {
    if fromNode.getLocation().getStartLine() = toNode.getLocation().getStartLine()
    then result = ""
    else result = ", l:" + fromNode.getLocation().getStartLine()
  }
}
