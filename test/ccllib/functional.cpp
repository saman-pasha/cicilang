// the twin of functional.c over <functional> (1.1.4): clang++ builds it over libc++, and it prints functional.expect,
// the lines that the C build and the C++ build of functional.c print. C++'s function objects are types whose call is
// the operator; ccllib's are macros that expand to the expression, so each line says the one and the other in its words
#include <cstdio>
#include <functional>
#include <set>
int main() {
    std::printf("compare: %d %d %d %d %d %d\n", std::less<int>{}(1, 2), std::greater<int>{}(1, 2),
                std::less_equal<int>{}(2, 2), std::greater_equal<int>{}(2, 2), std::equal_to<int>{}(2, 2),
                std::not_equal_to<int>{}(2, 2));
    std::printf("compare false: %d %d %d %d %d %d\n", std::less<int>{}(2, 1), std::greater<int>{}(2, 1),
                std::less_equal<int>{}(1, 2), std::greater_equal<int>{}(1, 2), std::equal_to<int>{}(2, 3),
                std::not_equal_to<int>{}(2, 2));
    std::printf("arith: %d %d %d %d %d %d\n", std::plus<int>{}(2, 3), std::minus<int>{}(2, 3),
                std::multiplies<int>{}(2, 3), std::divides<int>{}(7, 2), std::modulus<int>{}(7, 2),
                std::negate<int>{}(3));
    std::printf("float: %g %g %g %g\n", std::plus<double>{}(1.5, 2.5), std::minus<double>{}(5.5, 2.0),
                std::multiplies<double>{}(1.5, 2.0), std::divides<double>{}(5.0, 2.0));
    std::printf("logic: %d %d %d %d %d %d %d\n", std::logical_and<int>{}(1, 0), std::logical_or<int>{}(0, 2),
                std::logical_not<int>{}(0), std::bit_and<int>{}(6, 3), std::bit_or<int>{}(6, 3),
                std::bit_xor<int>{}(6, 3), std::bit_not<int>{}(0));
    auto identity = [](auto x) { return x; };
    std::printf("identity: %d %g\n", identity(7), identity(2.5));
    std::set<int, std::less<int>> a;
    a.insert(3);
    a.insert(1);
    a.insert(2);
    std::printf("less:");
    for (int x : a) std::printf(" %d", x);
    std::printf("\n");
    std::set<int, std::greater<int>> b;
    b.insert(3);
    b.insert(1);
    b.insert(2);
    std::printf("greater:");
    for (int x : b) std::printf(" %d", x);
    std::printf("\n");
    return 0;
}
