#include <cstdio>
#include <cstdlib>
#include <new>
// a placement allocation function of the program ([expr.new]/15, /27): `new (arena) T' calls `operator new(size_t,
// Arena &)', and where the initialization throws, the matching `operator delete(void *, Arena &)'; the block lies within
// the arena, the tie says, and the objects borrow it
struct Arena { char buf[256]; std::size_t used = 0; };
void *operator new(std::size_t n, Arena &a) tie a { std::printf("arena new %zu\n", n); void *p = a.buf + a.used; a.used += (n + 7) & ~(std::size_t) 7; return p; }
void operator delete(void *, Arena &) { std::printf("arena delete\n"); }
struct S { int v; S(int k) : v(k) { if (k < 0) throw k; } };
int main() {
  Arena ar;
  S *s = new (ar) S(4);
  S *t = new (ar) S(5);
  std::printf("%d %d %zu\n", s->v, t->v, ar.used);
  try { new (ar) S(-1); } catch (int e) { std::printf("caught %d\n", e); }
  return 0;
}
