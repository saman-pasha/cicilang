// a class caught by value is a copy, and a thrown temporary is built in the exception's memory (0.110)
#include <cstdio>
struct E {
  int v;
  E(int x) : v(x) { printf("E(%d)\n", v); }
  E(const E &o) : v(o.v + 100) { printf("copy E(%d)\n", v); }
  ~E() { printf("~E(%d)\n", v); }
};
int main() {
  try { throw E(1); } catch (E e) { printf("caught %d\n", e.v); e.v = 7; }
  try { throw E(2); } catch (const E &e) { printf("caught ref %d\n", e.v); }
  try { throw 5; } catch (int i) { printf("int %d\n", i); }
  return 0;
}
