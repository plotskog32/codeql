/**
 * @name Suspicious method name declaration
 * @description A method having the name "function", "new", or "constructor"
 *              is usually caused by a programmer being confused about the TypeScript syntax. 
 * @kind problem
 * @problem.severity warning
 * @id js/suspicious-method-name-declaration
 * @precision high
 * @tags correctness
 *       typescript
 *       methods
 */

import javascript

/**
 * Holds if the method name on the given container is likely to be a mistake.
 */
predicate isSuspisousMethodName(string name, ClassOrInterface container) {
  name = "function"
  or
  // "constructor" is only suspicious outside a class.  
  name = "constructor" and not container instanceof ClassDefinition
  or
  // "new" is only suspicious inside a class.
  name = "new" and container instanceof ClassDefinition
}

from MethodDeclaration member, ClassOrInterface container, string suffixMsg
where
  container.getLocation().getFile().getFileType().isTypeScript() and
  container.getAMember() = member and
  isSuspisousMethodName(member.getName(), container) and
  
  // Assume that a "new" method is intentional if the class has an explicit constructor.
  not (
    member.getName() = "new" and
    container instanceof ClassDefinition and
    exists(ConstructorDeclaration constructor |
      container.getAMember() = constructor and
      not constructor.isSynthetic() 
    )
  ) and
  
  // Explicitly declared static methods are fine.
  not (
    container instanceof ClassDefinition and
    member.isStatic()
  ) and
  
  // Only looking for declared methods. Methods with a body are OK. 
  not exists(member.getBody().getBody()) and
  
  // The developer was not confused about "function" when there are other methods in the interface.
  not (
    member.getName() = "function" and 
    exists(MethodDeclaration other | other = container.getMethod(_) |
      other.getName() != "function" and
      not other.(ConstructorDeclaration).isSynthetic()
    )
  ) and
  
  (
    member.getName() = "constructor" and suffixMsg = "Did you mean to write a class instead of an interface?" 
    or
    member.getName() = "new" and suffixMsg = "Did you mean \"constructor\"?"
    or
    member.getName() = "function" and suffixMsg = "Did you mean to omit \"function\"?"
  )
select member, "Declares a suspiciously named method \"" + member.getName() + "\". " + suffixMsg
