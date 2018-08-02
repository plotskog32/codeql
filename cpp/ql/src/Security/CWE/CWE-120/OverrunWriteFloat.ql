/**
 * @name Potentially overrunning write with float to string conversion
 * @description Buffer write operations that do not control the length
 *              of data written may overflow when floating point inputs
 *              take extreme values.
 * @kind problem
 * @problem.severity error
 * @precision medium
 * @id cpp/overrunning-write-with-float
 * @tags reliability
 *       security
 *       external/cwe/cwe-120
 *       external/cwe/cwe-787
 *       external/cwe/cwe-805
 */
import semmle.code.cpp.security.BufferWrite

// see CWE-120UnboundedWrite.ql for a summary of CWE-120 violation cases

from BufferWrite bw, int destSize
where (not bw.hasExplicitLimit())                // has no explicit size limit
  and destSize = getBufferSize(bw.getDest(), _)
  and (bw.getMaxData() > destSize)               // and we can deduce that too much data may be copied
  and (bw.getMaxDataLimited() <= destSize)       // but it would fit without long '%f' conversions
select bw, "This '" + bw.getBWDesc() + "' operation may require " + bw.getMaxData() + " bytes because of float conversions, but the target is only " + destSize + " bytes."
