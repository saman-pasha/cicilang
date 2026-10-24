#include <cstdio>
#include <malloc.h>
#include <memory>
#include <string>
// a new-expression whose constructor throws frees its block ([expr.new]/26); one that returns keeps it
struct T {
  char big[4000];
  std::string s;
  T(int v) : s(v > 2 ? "long enough to allocate a block of its own" : "x") { if (v > 2) throw 7; }
};
struct U { int k; explicit U(int v) : k(v) { if (v < 0) throw v; } };
int main() {
  for (int i = 0; i < 3; ++i) { try { T *p = new T(9); delete p; } catch (int) {} }
  size_t before = mallinfo2().uordblks;
  for (int i = 0; i < 100; ++i) { try { T *p = new T(9); delete p; } catch (int) {} }
  for (int i = 0; i < 100; ++i) { try { auto q = std::make_unique<U>(-1); } catch (int) {} }
  size_t after = mallinfo2().uordblks;
  T *ok = new T(1);
  U *u = new U(5);
  std::printf("%d %s %d\n", (int) (after - before > 100000), ok->s.c_str(), u->k);
  delete ok;
  delete u;
  return 0;
}
