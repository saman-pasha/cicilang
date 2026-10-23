#include <cstdio>
enum class A { x = 1, y = 2 };
enum class B { p = (int) A::y + 1, q };
namespace n { enum E { y = 10 }; }
enum C { c = n::y + 1 };
int main() { std::printf("%d %d %d\n", (int) B::p, (int) B::q, (int) c); }
