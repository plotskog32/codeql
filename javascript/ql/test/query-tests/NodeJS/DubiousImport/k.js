function foo() {
  return "foo";
}

module.exports = {
  [foo()]: 42
};