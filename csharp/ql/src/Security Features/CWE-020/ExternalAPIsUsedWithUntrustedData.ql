/**
 * @name Frequency counts for external APIs that are used with untrusted data
 * @description This reports the external APIs that are used with untrusted data, along with how
 *              frequently the API is called, and how many unique sources of untrusted data flow
 *              to it.
 * @id csharp/count-untrusted-data-external-api
 * @kind table
 * @tags security external/cwe/cwe-20
 */

import csharp
import semmle.code.csharp.security.dataflow.ExternalAPIs
import semmle.code.csharp.dataflow.DataFlow

from ExternalAPIUsedWithUntrustedData externalAPI
select externalAPI, count(externalAPI.getUntrustedDataNode()) as numberOfUses,
  externalAPI.getNumberOfUntrustedSources() as numberOfUntrustedSources order by
    numberOfUntrustedSources desc
