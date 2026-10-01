// a base with constructors, none of them a default one, named by no initializer: C++ refuses the program
#include <cstdio>
struct B { int v; B(int x) : v(x) {} };
struct D : B { int w; D() : w(2) {} };
int main() { D d; std::printf("%d\n", d.w); return 0; }
