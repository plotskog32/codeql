/**
 * @name Number of Solorigate-related literals is above the threshold 
 * @description The total number of Solorigate-related literals found in the code is above a threshold, which may indicate that the code may have been tampered by an external agent.
 *      It is recommended to review the code and verify that there is no unexpected code in this project.
 * @kind problem
 * @tags security
 *       solorigate
 * @problem.severity warning
 * @precision medium
 * @id cs/solorigate/number-of-known-literals-above-threshold
 */

import csharp
import Solorigate


from Literal l, int total, int threshold
where total = countSolorigateSuspiciousLiterals()
	and threshold = 30 // out of ~150 known literals
	and isSolorigateLiteral(l)
	and total > threshold
select l, "The literal $@ may be related to the Solorigate campaign. Total count = " + total + " is above the threshold " + threshold + "."
	, l, l.getValue()