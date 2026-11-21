// An assignment is an lvalue in C++ (1.6.13), its left operand: a function that returns `int &' to a local through
// one returns the local's address, refused as a borrow that leaves the function. Through 1.6.12 the result was a
// temporary's address, as dead, with no word
#include <cstdio>
int &f() { int x = 1; return (x = 5); }
int main() { std::printf("%d\n", f()); return 0; }
