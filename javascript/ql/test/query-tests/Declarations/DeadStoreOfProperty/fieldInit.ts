class C {
  f; // OK
  
  constructor() {
    this.f = 5;
  }
}

class D {
  f = 4; // NOT OK
  
  constructor() {
    this.f = 5;
  }
}
