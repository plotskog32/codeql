
__attribute__((format(printf, 2, 3)))
void myMultiplyDefinedPrintf(const char *extraArg, const char *format, ...); // this declaration does not match the definition

__attribute__((format(printf, 2, 3)))
void myMultiplyDefinedPrintf2(const char *extraArg, const char *format, ...);

char *getString();

void test_custom_printf2(char *string)
{
  myMultiplyDefinedPrintf("string", getString()); // GOOD [FALSE POSITIVE]
  myMultiplyDefinedPrintf(getString(), "string"); // BAD
  myMultiplyDefinedPrintf2("string", getString()); // GOOD (we can't tell which definition is correct so we have to assume this is OK) [FALSE POSITIVE]
  myMultiplyDefinedPrintf2(getString(), "string"); // GOOD (we can't tell which definition is correct so we have to assume this is OK) [FALSE POSITIVE]
}