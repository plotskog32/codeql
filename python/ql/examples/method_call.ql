/**
 * @name Call to method
 * @description Finds calls to MyClass.methodName
 * @tags call
 *       method
 */
 
import python

from AstNode call, FunctionObject method
where 
    method.getQualifiedName() = "MyClass.methodName" and
    method.getACall().getNode() = call
select call
