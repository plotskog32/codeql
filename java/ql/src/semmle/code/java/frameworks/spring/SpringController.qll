import java
import SpringWeb

/**
 * An annotation type that identifies Spring components.
 */
class SpringControllerAnnotation extends AnnotationType {
  SpringControllerAnnotation() {
    // `@Controller` used directly as an annotation.
    hasQualifiedName("org.springframework.stereotype", "Controller")
    or
    // `@Controller` can be used as a meta-annotation on other annotation types.
    getAnAnnotation().getType() instanceof SpringControllerAnnotation
  }
}

/**
 * A class annotated, directly or indirectly, as a Spring `Controller`.
 */
class SpringController extends Class {
  SpringController() { getAnAnnotation().getType() instanceof SpringControllerAnnotation }
}

/**
 * A method on a Spring controller which is accessed by the Spring MVC framework.
 */
abstract class SpringControllerMethod extends Method {
  SpringControllerMethod() { getDeclaringType() instanceof SpringController }
}

/**
 * A method on a Spring controller that builds a "model attribute" that will be returned with the
 * response as part of the model.
 */
class SpringModelAttributeMethod extends SpringControllerMethod {
  SpringModelAttributeMethod() {
    // Any method that declares the @ModelAttribute annotation, or overrides a method that declares
    // the annotation. We have to do this explicit check because the @ModelAttribute annotation is
    // not declared with @Inherited.
    exists(Method superMethod |
      this.overrides*(superMethod) and
      superMethod.hasAnnotation("org.springframework.web.bind.annotation", "ModelAttribute")
    )
  }
}

/**
 * A method on a Spring controller that configures a binder for this controller.
 */
class SpringInitBinderMethod extends SpringControllerMethod {
  SpringInitBinderMethod() {
    // Any method that declares the @InitBinder annotation, or overrides a method that declares
    // the annotation. We have to do this explicit check because the @InitBinder annotation is
    // not declared with @Inherited.
    exists(Method superMethod |
      this.overrides*(superMethod) and
      superMethod.hasAnnotation("org.springframework.web.bind.annotation", "InitBinder")
    )
  }
}

/**
 * An `AnnotationType` which is used to indicate a `RequestMapping`.
 */
class SpringRequestMappingAnnotationType extends AnnotationType {
  SpringRequestMappingAnnotationType() {
    // `@RequestMapping` used directly as an annotation.
    hasQualifiedName("org.springframework.web.bind.annotation", "RequestMapping")
    or
    // `@RequestMapping` can be used as a meta-annotation on other annotation types, e.g. GetMapping, PostMapping etc.
    getAnAnnotation().getType() instanceof SpringRequestMappingAnnotationType
  }
}

/**
 * A method on a Spring controller that is executed in response to a web request.
 */
class SpringRequestMappingMethod extends SpringControllerMethod {
  SpringRequestMappingMethod() {
    // Any method that declares the @RequestMapping annotation, or overrides a method that declares
    // the annotation. We have to do this explicit check because the @RequestMapping annotation is
    // not declared with @Inherited.
    exists(Method superMethod |
      this.overrides*(superMethod) and
      superMethod.getAnAnnotation().getType() instanceof SpringRequestMappingAnnotationType
    )
  }

  /** Gets a request mapping parameter. */
  SpringRequestMappingParameter getARequestParameter() {
    result = getAParameter()
  }
}

/** A Spring framework annotation indicating remote user input from servlets. */
class SpringServletInputAnnotation extends Annotation {
  SpringServletInputAnnotation() {
    exists(AnnotationType a |
      a = this.getType() and
      a.getPackage().getName() = "org.springframework.web.bind.annotation"
    |
      a.hasName("MatrixVariable") or
      a.hasName("RequestParam") or
      a.hasName("RequestHeader") or
      a.hasName("CookieValue") or
      a.hasName("RequestPart") or
      a.hasName("PathVariable") or
      a.hasName("RequestBody")
    )
  }
}

class SpringRequestMappingParameter extends Parameter {
  SpringRequestMappingParameter() { getCallable() instanceof SpringRequestMappingMethod }

  /** Holds if the parameter should not be consider a direct source of taint. */
  predicate isNotDirectlyTaintedInput() {
    getType().(RefType).getAnAncestor() instanceof SpringWebRequest or
    getType().(RefType).getAnAncestor() instanceof SpringNativeWebRequest or
    getType().(RefType).getAnAncestor().hasQualifiedName("javax.servlet", "ServletRequest") or
    getType().(RefType).getAnAncestor().hasQualifiedName("javax.servlet", "ServletResponse") or
    getType().(RefType).getAnAncestor().hasQualifiedName("javax.servlet.http", "HttpSession") or
    getType().(RefType).getAnAncestor().hasQualifiedName("javax.servlet.http", "PushBuilder") or
    getType().(RefType).getAnAncestor().hasQualifiedName("java.security", "Principal") or
    getType().(RefType).getAnAncestor().hasQualifiedName("org.springframework.http", "HttpMethod") or
    getType().(RefType).getAnAncestor().hasQualifiedName("java.util", "Locale") or
    getType().(RefType).getAnAncestor().hasQualifiedName("java.util", "TimeZone") or
    getType().(RefType).getAnAncestor().hasQualifiedName("java.time", "ZoneId") or
    getType().(RefType).getAnAncestor().hasQualifiedName("java.io", "OutputStream") or
    getType().(RefType).getAnAncestor().hasQualifiedName("java.io", "Writer") or
    getType().(RefType).getAnAncestor().hasQualifiedName("org.springframework.web.servlet.mvc.support", "RedirectAttributes") or
    // Also covers BindingResult. Note, you can access the field value through this interface, which should be considered tainted
    getType().(RefType).getAnAncestor().hasQualifiedName("org.springframework.validation", "Errors") or
    getType().(RefType).getAnAncestor().hasQualifiedName("org.springframework.web.bind.support", "SessionStatus") or
    getType().(RefType).getAnAncestor().hasQualifiedName("org.springframework.web.util", "UriComponentsBuilder") or
    this instanceof SpringModel
  }

  predicate isTaintedInput() {
    // InputStream or Reader parameters allow access to the body of a request
    getType().(RefType).getAnAncestor().hasQualifiedName("java.io", "InputStream") or
    getType().(RefType).getAnAncestor().hasQualifiedName("java.io", "Reader") or
    // The SpringServletInputAnnotations allow access to the URI, request parameters, cookie values and the body of the request
    this.getAnAnnotation() instanceof SpringServletInputAnnotation or
    // HttpEntity is like @RequestBody, but with a wrapper including the headers
    // TODO model unwrapping aspects
    getType().(RefType).getAnAncestor().hasQualifiedName("org.springframework.http", "HttpEntity<T>") or
    this.getAnAnnotation().getType().hasQualifiedName("org.springframework.web.bind.annotation", "RequestAttribute") or
    this.getAnAnnotation().getType().hasQualifiedName("org.springframework.web.bind.annotation", "SessionAttribute") or
    // Any parameter which is not explicitly identified, is consider to be an `@RequestParam`, if
    // it is a simple bean property) or a @ModelAttribute if not
    not isNotDirectlyTaintedInput()
  }
}

/**
 * A parameter to a `SpringRequestMappingMethod` which represents a model that can be populated by
 * the method, which will be used to render the response e.g. as a JSP file.
 */
abstract class SpringModel extends Parameter {
  SpringModel() { getCallable() instanceof SpringRequestMappingMethod }

  /**
   * Types for which instances are placed inside the model.
   */
  abstract RefType getATypeInModel();
}

/**
 * A `java.util.Map` can be accepted as the model parameter for a Spring `RequestMapping` method.
 */
class SpringModelPlainMap extends SpringModel {
  SpringModelPlainMap() { getType().(RefType).hasQualifiedName("java.util", "Map") }

  override RefType getATypeInModel() {
    exists(MethodAccess methodCall |
      methodCall.getQualifier() = getAnAccess() and
      methodCall.getCallee().hasName("put")
    |
      result = methodCall.getArgument(1).getType()
    )
  }
}

/**
 * A Spring `Model` or `ModelMap` can be accepted as the model parameter for a Spring `RequestMapping`
 * method.
 */
class SpringModelModel extends SpringModel {
  SpringModelModel() {
    getType().(RefType).hasQualifiedName("org.springframework.ui", "Model") or
    getType().(RefType).hasQualifiedName("org.springframework.ui", "ModelMap")
  }

  override RefType getATypeInModel() {
    exists(MethodAccess methodCall |
      methodCall.getQualifier() = getAnAccess() and
      methodCall.getCallee().hasName("addAttribute")
    |
      result = methodCall.getArgument(methodCall.getNumArgument() - 1).getType()
    )
  }
}

/**
 * A `RefType` that is included in a model that is used in a response by the Spring MVC.
 */
class SpringModelResponseType extends RefType {
  SpringModelResponseType() {
    exists(SpringModelAttributeMethod modelAttributeMethod |
      this = modelAttributeMethod.getReturnType()
    ) or
    exists(SpringModel model | usesType(model.getATypeInModel(), this))
  }
}
