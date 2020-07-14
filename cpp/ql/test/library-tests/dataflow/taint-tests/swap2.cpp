#include "swap.h"
/*
 * Note: This file exists in two versions (swap1.cpp and swap2.cpp).
 * The only difference is that `IntWrapper` in swap1.cpp contains a single data member, and swap2.cpp
 * contains two data members.
 */

int source();
void sink(...);

namespace std
{
    template <class T>
    T &&move(T &t) noexcept { return static_cast<T &&>(t); } // simplified signature (and implementation)
} // namespace std

namespace IntWrapper
{
    struct Class
    {
        int data1; int data2;

        Class() = default;
        Class(Class &&that) { swap(that); }
        Class(const Class &that) : data1(that.data1), data2(that.data2) {}

        Class &operator=(const Class &that)
        {
            auto tmp = that;
            swap(tmp);
            return *this;
        }

        Class &operator=(Class &&that)
        {
            swap(that);
            return *this;
        }

        Class &copy_assign(const Class &that) // copy assignment without the usual signature
        {
            auto tmp = that;
            swap(tmp);
            return *this;
        }

        Class &move_assign(Class &&that) // move assignment without the usual signature
        {
            swap(that);
            return *this;
        }

        void swap(Class &that) noexcept
        {
            using std::swap;
            swap(data1, that.data1); swap(data2, that.data2);
        }
    };

    // For ADL
    void swap(Class &x, Class &y)
    {
        x.swap(y);
    }
} // namespace IntWrapper

void test_copy_assignment_operator()
{
    IntWrapper::Class x;
    IntWrapper::Class y;
    x.data1 = source();

    sink(x.data1); // tainted
    sink(y.data1); // clean

    y = x;

    sink(y.data1); // tainted
    sink(x.data1); // tainted

    IntWrapper::Class z1, z2;
    z1.data1 = source();
    sink(z1.data1); // tainted

    swap(z1, z2);

    sink(z2.data1); // tainted [FALSE NEGATIVE in IR]
    sink(z1.data1); // clean [FALSE POSITIVE]
}

void test_move_assignment_operator()
{
    IntWrapper::Class x;
    IntWrapper::Class y;
    x.data1 = source();

    sink(x.data1); // tainted
    sink(y.data1); // clean

    y = std::move(x);

    sink(y.data1); // tainted
    sink(x.data1); // tainted
}

void test_move_constructor()
{
    IntWrapper::Class move_from;
    move_from.data1 = source();

    sink(move_from.data1); // tainted

    IntWrapper::Class move_to(std::move(move_from));

    sink(move_to.data1); // tainted
}

void test_copy_assignment_method()
{
    IntWrapper::Class x;
    IntWrapper::Class y;
    x.data1 = source();

    sink(x.data1); // tainted
    sink(y.data1); // clean

    y.copy_assign(x);

    sink(y.data1); // tainted
    sink(x.data1); // tainted
}

void test_move_assignment_method()
{
    IntWrapper::Class x;
    IntWrapper::Class y;
    x.data1 = source();

    sink(x.data1); // tainted
    sink(y.data1); // clean

    y.move_assign(std::move(x));

    sink(y.data1); // tainted
    sink(x.data1); // tainted
}
