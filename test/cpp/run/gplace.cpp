#include <cstdio>
#include <cstdlib>
#include <new>
// a program's global placement allocation function over a pointer to an object
struct Arena { char buf[64]; int used = 0; };
void *operator new(std::size_t n, Arena *a) tie a { std::printf("arena new %zu\n", n); void *p = a->buf + a->used; a->used += (int) n; return p; }
struct S { int v; S() : v(7) {} };
int main() {
  Arena ar;
  S *s = new (&ar) S;
  std::printf("%d %d\n", s->v, ar.used);
  return 0;
}
