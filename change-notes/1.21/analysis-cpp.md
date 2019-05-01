# Improvements to C/C++ analysis

## General improvements

## New queries

| **Query**                   | **Tags**  | **Purpose**                                                        |
|-----------------------------|-----------|--------------------------------------------------------------------|
| `()`-declared function called with too few arguments (`cpp/too-few-arguments`) | Correctness | Find all cases where the number of arguments is less than the number of parameters of the function, provided the function is also properly declared/defined elsewhere. |
| `()`-declared function called with mismatched arguments (`cpp/mismatched-function-arguments`) | Correctness | Find all cases where the types of arguments do not match the types of parameters of the function, provided the function is also properly declared/defined elsewhere. |
| Call to alloca in a loop (`cpp/alloca-in-loop`) | reliability, correctness, external/cwe/cwe-770 | Finds calls to `alloca` in loops, which can lead to stack overflow if the number of iterations is large.  Newly displayed on LGTM. |

## Changes to existing queries

| **Query**                  | **Expected impact**    | **Change**                                                       |
|----------------------------|------------------------|------------------------------------------------------------------|
| Buffer not sufficient for string (`cpp/overflow-calculated`) | Fewer results | This query no longer reports results that would be found by the 'No space for zero terminator' (`cpp/no-space-for-terminator`) query. |
| No space for zero terminator (`cpp/no-space-for-terminator`) | More correct results | This query now detects calls to `std::malloc`. |
| Commented-out code (`cpp/commented-out-code`) | More correct results | Commented out preprocessor code is now detected by this query. |
| Dead code due to goto or break statement (`cpp/dead-code-goto`) | Fewer false positive results | Functions containing preprocessor logic are now excluded from this analysis. |
| Mismatching new/free or malloc/delete (`cpp/new-free-mismatch`) | Fewer false positive results | Fixed an issue where functions were being identified as allocation functions inappropriately.  Also affects `cpp/new-array-delete-mismatch` and `cpp/new-delete-array-mismatch`. |
| Overflow in uncontrolled allocation size (`cpp/uncontrolled-allocation-size`) | More correct results | This query has been reworked so that it can find a wider variety of results. |
| Memory may not be freed (`cpp/memory-may-not-be-freed`) | More correct results | Support added for more Microsoft-specific allocation functions, including `LocalAlloc`, `GlobalAlloc`, `HeapAlloc` and `CoTaskMemAlloc`. |
| Memory is never freed (`cpp/memory-never-freed`) | More correct results | Support added for more Microsoft-specific allocation functions, including `LocalAlloc`, `GlobalAlloc`, `HeapAlloc` and `CoTaskMemAlloc`. |
| Resource not released in destructor (`cpp/resource-not-released-in-destructor`) | Fewer false positive results | Resource allocation and deallocation functions are now determined more accurately. |
| Comparison result is always the same | Fewer false positive results | The range analysis library is now more conservative about floating point values being possibly `NaN` |
| Use of potentially dangerous function | More correct results | Calls to `localtime`, `ctime` and `asctime` are now detected by this query. |
| Wrong type of arguments to formatting function (`cpp/wrong-type-format-argument`) | More correct results and fewer false positive results | This query now more accurately identifies wide and non-wide string/character format arguments on different platforms.  Platform detection has also been made more accurate for the purposes of this query. |
| Wrong type of arguments to formatting function (`cpp/wrong-type-format-argument`) | Fewer false positive results | Non-standard uses of %L are now understood. |
| `()`-declared function called with too many arguments (`cpp/futile-params`) | Improved coverage | Query has been generalized to find all cases where the number of arguments exceedes the number of parameters of the function, provided the function is also properly declared/defined elsewhere. |

## Changes to QL libraries
- Additional support for definition by reference has been added to the `semmle.code.cpp.dataflow.TaintTracking` library.
    - The taint tracking library now includes taint-specific edges for functions modeled in `semmle.code.cpp.models.interfaces.DataFlow`.
    - The taint tracking library adds flow through library functions that are modeled in `semmle.code.cpp.models.interfaces.Taint`. Queries can add subclasses of `TaintFunction` to specify additional flow.
