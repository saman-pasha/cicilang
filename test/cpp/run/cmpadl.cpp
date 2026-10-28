// a program's strong_order found by argument-dependent lookup from std::strong_order (0.221): ns::strong_order is keyed apart
// from the library's object, and libc++'s __strong_order::__fn finds it through the argument's class
#include <compare>
#include <cstdio>
namespace ns { struct Q { int v; }; std::strong_ordering strong_order(const Q &x, const Q &y) { return y.v <=> x.v; } }
int main() { std::printf("%d %d\n", (int)(std::strong_order(ns::Q{1}, ns::Q{2}) > 0), (int)(std::strong_order(1, 2) < 0)); return 0; }
