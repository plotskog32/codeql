/**
 * @name Filter out generated files
 * @description Only keep results from files that do not look like they are minified,
 *              generated by a module bundler or by Emscripten, or contain a source
 *              mapping comment.
 * @kind problem
 * @id js/not-generated-file-filter
 */

import semmle.javascript.GeneratedCode
import external.DefectFilter

from DefectResult defres
where not isGeneratedCode(defres.getFile())
select defres, defres.getMessage()