// semmle-extractor-options: --edg --target --edg linux_i686
/*
 * Test for printf in a snapshot that contains multiple word/pointer sizes.
 */

int printf(const char * format, ...);

void test_32()
{
	long l;
	void *void_ptr;

	printf("%li", l); // GOOD
	printf("%li", void_ptr); // BAD
	printf("%p", l); // BAD [NOT DETECTED]
	printf("%p", void_ptr); // GOOD
}
