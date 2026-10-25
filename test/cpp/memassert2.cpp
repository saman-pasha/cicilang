#include <cstdio>
template <class T> struct B { T x; static_assert(sizeof(T) > 1, "too small"); };
int main() { B<char> b{1}; std::printf("%d\n", b.x); return 0; }
