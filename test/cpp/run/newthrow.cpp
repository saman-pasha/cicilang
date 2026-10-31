#include <cstdio>
#if defined(__APPLE__)
#include <malloc/malloc.h>
static size_t in_use() { malloc_statistics_t s; malloc_zone_statistics(nullptr, &s); return s.size_in_use; }   // macOS's heap (0.250)
#else
#include <malloc.h>
static size_t in_use() { return mallinfo2().uordblks; }   // glibc's mallinfo2 is no part of macOS's
#endif
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
  size_t before = in_use();
  for (int i = 0; i < 100; ++i) { try { T *p = new T(9); delete p; } catch (int) {} }
  for (int i = 0; i < 100; ++i) { try { auto q = std::make_unique<U>(-1); } catch (int) {} }
  size_t after = in_use();
  T *ok = new T(1);
  U *u = new U(5);
  std::printf("%d %s %d\n", (int) (after - before > 100000), ok->s.c_str(), u->k);
  delete ok;
  delete u;
  return 0;
}
