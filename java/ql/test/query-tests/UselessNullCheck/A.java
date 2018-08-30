public class A {
  void f() {
    Object o = new Object();
    if (o == null) { } // Useless check
    if (o != null) { } // Useless check
    try {
      new Object();
    } catch(Exception e) {
      if (e == null) { // Useless check
        throw new Exception();
      }
    }
  }

  void g(Object o) {
    if (o instanceof A) {
      A a = (A)o;
      if (a != null) { // Useless check
        throw new Exception();
      }
    }
  }

  interface I {
    A get();
  }

  I h() {
    final A x = this;
    return () -> {
      if (x != null) { // Useless check
        return x;
      }
      return new A();
    };
  }

  Object f2(Object x) {
    if (x == null) {
      return this != null ? this : null; // Useless check
    }
    if (x != null) { // Useless check
      return x;
    }
    return null;
  }
}
