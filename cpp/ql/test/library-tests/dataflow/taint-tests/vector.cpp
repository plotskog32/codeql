
#include "stl.h"

using namespace std;

int source();

namespace ns_char
{
	char source();
}

void sink(int);
void sink(std::vector<int> &);

void test_range_based_for_loop_vector(int source1) {
	std::vector<int> v(100, source1);

	for(int x : v) {
		sink(x); // tainted [NOT DETECTED by IR]
	}

	for(std::vector<int>::iterator it = v.begin(); it != v.end(); ++it) {
		sink(*it); // tainted [NOT DETECTED]
	}

	for(int& x : v) {
		sink(x); // tainted [NOT DETECTED by IR]
	}

	const std::vector<int> const_v(100, source1);
	for(const int& x : const_v) {
		sink(x); // tainted [NOT DETECTED by IR]
	}
}

void test_element_taint(int x) {
	std::vector<int> v1(10), v2(10), v3(10), v4(10), v5(10), v6(10), v7(10), v8(10), v9(10);

	v1[0] = 0;
	v1[1] = 0;
	v1[x] = 0;
	v1.push_back(1);
	sink(v1);
	sink(v1[0]);
	sink(v1[1]);
	sink(v1[x]);
	sink(v1.front());
	sink(v1.back());

	v2[0] = source();
	sink(v2); // tainted [NOT DETECTED]
	sink(v2[0]); // tainted [NOT DETECTED]
	sink(v2[1]);
	sink(v2[x]); // potentially tainted

	v3 = v2;
	sink(v3); // tainted [NOT DETECTED]
	sink(v3[0]); // tainted [NOT DETECTED]
	sink(v3[1]);
	sink(v3[x]); // potentially tainted

	v4[x] = source();
	sink(v4); // tainted [NOT DETECTED]
	sink(v4[0]); // potentially tainted
	sink(v4[1]); // potentially tainted
	sink(v4[x]); // tainted [NOT DETECTED]

	v5.push_back(source());
	sink(v5); // tainted
	sink(v5.front()); // [FALSE POSITIVE]
	sink(v5.back()); // tainted

	v6.data()[2] = source();
	sink(v6); // tainted [NOT DETECTED]
	sink(v6.data()[2]); // tainted [NOT DETECTED]

	{
		const std::vector<int> &v7c = v7; // (workaround because our iterators don't convert to const_iterator)
		std::vector<int>::const_iterator it = v7c.begin();
		v7.insert(it, source());
	}
	sink(v7); // tainted [NOT DETECTED]
	sink(v7.front()); // tainted [NOT DETECTED]
	sink(v7.back());

	{
		const std::vector<int> &v8c = v8;
		std::vector<int>::const_iterator it = v8c.begin();
		v8.insert(it, 10, ns_char::source());
	}
	sink(v8); // tainted [NOT DETECTED]
	sink(v8.front()); // tainted [NOT DETECTED]
	sink(v8.back());

	v9.at(x) = source();
	sink(v9); // tainted [NOT DETECTED]
	sink(v9.at(0)); // potentially tainted
	sink(v9.at(1)); // potentially tainted
	sink(v9.at(x)); // tainted [NOT DETECTED]
}

void test_vector_swap() {
	std::vector<int> v1(10), v2(10), v3(10), v4(10);

	v1.push_back(source());
	v4.push_back(source());

	sink(v1); // tainted
	sink(v2);
	sink(v3);
	sink(v4); // tainted

	v1.swap(v2);
	v3.swap(v4);

	sink(v1); // [FALSE POSITIVE]
	sink(v2); // tainted
	sink(v3); // tainted
	sink(v4); // [FALSE POSITIVE]
}

void test_vector_clear() {
	std::vector<int> v1(10), v2(10), v3(10), v4(10);

	v1.push_back(source());
	v2.push_back(source());
	v3.push_back(source());

	sink(v1); // tainted
	sink(v2); // tainted
	sink(v3); // tainted
	sink(v4);

	v1.clear();
	v2 = v2;
	v3 = v4;

	sink(v1); // [FALSE POSITIVE]
	sink(v2); // tainted
	sink(v3); // [FALSE POSITIVE]
	sink(v4);
}
