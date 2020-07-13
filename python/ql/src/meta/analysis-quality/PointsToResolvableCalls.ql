/**
 * @name Resolvable calls by points-to
 * @description The number of (relevant) calls that can be resolved to a target.
 * @kind metric
 * @metricType project
 * @metricAggregate sum
 * @tags meta
 * @id py/meta/points-to-resolvable-calls
 */

import python
import CallGraphQuality

select projectRoot(), count(PointsTo::ResolvableCall call)
