/**
 * @name Resolved call ratio
 * @description The percentage of non-external calls that can be resolved to a target.
 * @kind metric
 * @metricType project
 * @metricAggregate sum min max avg
 * @tags meta
 * @id js/meta/resolved-call-ratio
 */
import javascript
import CallGraphQuality

select projectRoot(), 100.0 * count(ResolvedCall call) / (float) count(NonExternalCall call)
