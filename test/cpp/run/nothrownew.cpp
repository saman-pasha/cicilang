#include <cstdio>
#include <cstdlib>
#include <new>
// `new (std::nothrow) T' ([expr.new]/20, [new.delete.single]/5): the nothrow allocation function, its null result
// tested before the initialization runs, which it then does not
static bool refuse;
void *operator new(std::size_t n, const std::nothrow_t &) noexcept { std::printf("nothrow new\n"); return refuse ? nullptr : std::malloc(n); }
struct C { int v; C() : v(5) { std::printf("C()\n"); } ~C() { std::printf("~C\n"); } };
int main() {
  C *c = new (std::nothrow) C;
  std::printf("%d\n", c ? c->v : -1);
  delete c;
  refuse = true;
  C *d = new (std::nothrow) C;
  std::printf("%d\n", d == nullptr);
  int *k = new (std::nothrow) int(3);
  std::printf("%d\n", k == nullptr);
  delete d;
  delete k;
  return 0;
}
