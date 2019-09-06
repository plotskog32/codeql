/**
 * Provides classes for performing local (intra-procedural) and
 * global (inter-procedural) taint-tracking analyses.
 *
 * We define _taint propagation_ informally to mean that a substantial part of
 * the information from the source is preserved at the sink. For example, taint
 * propagates from `x` to `x + 100`, but it does not propagate from `x` to `x >
 * 100` since we consider a single bit of information to be too little.
 *
 * To use global (interprocedural) taint tracking, extend the class
 * `TaintTracking::Configuration` as documented on that class. To use local
 * (intraprocedural) taint tracking between expressions, call
 * `TaintTracking::localExprTaint`. For more general cases of local taint
 * tracking, call `TaintTracking::localTaint` or
 * `TaintTracking::localTaintStep` with arguments of type `DataFlow::Node`.
 */

import semmle.code.cpp.ir.dataflow.DataFlow
import semmle.code.cpp.ir.dataflow.DataFlow2

module TaintTracking {
  import semmle.code.cpp.ir.dataflow.internal.tainttracking1.TaintTrackingImpl
  private import semmle.code.cpp.ir.dataflow.TaintTracking2

  /**
   * DEPRECATED: Use TaintTracking2::Configuration instead.
   */
  deprecated class Configuration2 = TaintTracking2::Configuration;
}
