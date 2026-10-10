/* a lambda that is not mutable calls a non-const member function on a by-value capture, which is const there: refused by name (0.127) */
#include <cstdio>
struct Counter { int n = 0; void bump() { ++n; } int get() const { return n; } };
int main() { Counter c; auto f = [c]() { c.bump(); return c.get(); }; std::printf("%d\n", f()); return 0; }
