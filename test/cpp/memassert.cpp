#include <cstdio>
struct A { int x; static_assert(sizeof(int) == 8, "int is eight"); };
int main() { A a{1}; std::printf("%d\n", a.x); return 0; }
