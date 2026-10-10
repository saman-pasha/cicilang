// AN AGGREGATE'S BASE WITH STORAGE TAKES ITS ITEM BEFORE THE MEMBERS ([dcl.init.aggr]/4.2; 0.127): `D d{}' of
// `struct D : Q { int b; }' never ran Q's constructor, and `D d2{{}, 4}' gave b the base's `{}'.
#include <cstdio>
struct Q { int a; Q() : a(5) {} };
struct D : Q { int b; };
struct E : Q { int b = 9; int c; };
__attribute__((noinline)) void dirty() { volatile unsigned char big[1024]; for (int i = 0; i < 1024; i++) big[i] = 0xAB; }
__attribute__((noinline)) void run() {
  D d{};
  D d2{{}, 4};
  E e{};
  std::printf("%d %d %d %d %d %d %d\n", d.a, d.b, d2.a, d2.b, e.a, e.b, e.c);
}
int main() { dirty(); run(); return 0; }
