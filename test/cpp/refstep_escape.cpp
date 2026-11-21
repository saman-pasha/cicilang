// A prefix ++ is an lvalue in C++ (1.6.13), its operand: `return ++x;' from a function that returns `int &' returns a
// local's address, refused as a borrow that leaves the function
#include <cstdio>
int &f() { int x = 1; return ++x; }
int main() { std::printf("%d\n", f()); return 0; }
