// two conversion functions chosen by the target, in a class and in a class template (operator T() of S<long> is a long)
#include <cstdio>
template <class T> struct S { T k; operator int() const { return (int)k + 1; } operator T() const { return k * 2; } };
struct Q { long k; operator int() const { return (int)k + 1; } operator long() const { return k * 2; } };
int main() { S<long> s{10}; int i = s; long t = s; Q q{10}; int i2 = q; long t2 = q; std::printf("%d %ld %d %ld\n", i, t, i2, t2); return 0; }
