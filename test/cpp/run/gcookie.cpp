#include <cstdio>
#include <cstdlib>
#include <new>
// `::new T[n]' and `::delete[]' use the GLOBAL functions ([expr.new]/12, [expr.delete]/10): no class-specific sized
// `operator delete[]' decides the array cookie, which a class with nothing to destroy keeps only for its own
static int last;
void *operator new[](std::size_t n) { last = (int) n; return std::malloc(n); }
void operator delete[](void *p) noexcept { std::free(p); }
void operator delete[](void *p, std::size_t) noexcept { std::free(p); }
struct T {
  int v = 7;
  static void *operator new[](std::size_t n) { std::printf("T::new[] %zu\n", n); return std::malloc(n); }
  static void operator delete[](void *p, std::size_t n) { std::printf("T::delete[] %zu\n", n); std::free(p); }
};
int main() {
  T *a = new T[3];
  std::printf("%d\n", a[2].v);
  delete[] a;
  T *g = ::new T[3];
  std::printf("%d %d\n", g[2].v, last);
  ::delete[] g;
  return 0;
}
