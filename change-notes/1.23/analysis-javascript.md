# Improvements to JavaScript analysis

## General improvements

* Support for the following frameworks and libraries has been improved:
  - [firebase](https://www.npmjs.com/package/firebase)
  - [mongodb](https://www.npmjs.com/package/mongodb)
  - [mongoose](https://www.npmjs.com/package/mongoose)
  - [rate-limiter-flexible](https://www.npmjs.com/package/rate-limiter-flexible)

* The call graph has been improved to resolve method calls in more cases. This may produce more security alerts.

## New queries

| **Query**                                                                 | **Tags**                                                          | **Purpose**                                                                                                                                                                            |
|---------------------------------------------------------------------------|-------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Unused index variable (`js/unused-index-variable`)                        | correctness                                                       | Highlights loops that iterate over an array, but do not use the index variable to access array elements, indicating a possible typo or logic error. |


## Changes to existing queries

| **Query**                      | **Expected impact**          | **Change**                                                                |
|--------------------------------|------------------------------|---------------------------------------------------------------------------|
| Incomplete string escaping or encoding (`js/incomplete-sanitization`) | Fewer false-positive results | This rule now recognizes additional ways delimiters can be stripped away. |
| Client-side cross-site scripting (`js/xss`) | More results | More potential vulnerabilities involving functions that manipulate DOM attributes are now recognized. |
| Code injection (`js/code-injection`) | More results | More potential vulnerabilities involving functions that manipulate DOM event handler attributes are now recognized. |
| Hard-coded credentials (`js/hardcoded-credentials`) | Fewer false-positive results | This rule now flags fewer password examples. |
| Incorrect suffix check (`js/incorrect-suffix-check`) | Fewer false-positive results | The query recognizes valid checks in more cases. 
| Network data written to file (`js/http-to-file-access`) | Fewer false-positive results | This query has been renamed to better match its intended purpose, and now only considers network data untrusted. | 
| Password in configuration file (`js/password-in-configuration-file`) | Fewer false-positive results | This rule now flags fewer password examples. |
| Prototype pollution (`js/prototype-pollution`) | More results | The query now highlights vulnerable uses of jQuery and Angular, and the results are shown on LGTM by default. |
| Uncontrolled command line (`js/command-line-injection`) | More results | This query now treats responses from servers as untrusted. |

## Changes to QL libraries

* `Expr.getDocumentation()` now handles chain assignments.
