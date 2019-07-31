/**
 * @id py/examples/new-instance
 * @name Create new object
 * @description Finds places where we create a new instanceof `MyClass`
 * @tags call
 *       constructor
 *       new
 */
 
import python

from Call new, ClassObject cls
where
    cls.getName() = "MyClass" and
    new.getFunc().refersTo(cls)
select new
