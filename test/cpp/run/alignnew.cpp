#include <cstdio>
#include <cstdlib>
#include <new>
// C++17's new of an over-aligned type ([expr.new]/19, [new.delete.single]): `operator new(size_t, align_val_t)' and
// the matching delete, replaced by the program; a type of the default alignment takes the plain one
static void *aligned(std::size_t n, std::size_t a) { void *p = nullptr; if (posix_memalign(&p, a, n)) throw std::bad_alloc(); return p; }
void *operator new(std::size_t n, std::align_val_t a) { std::printf("new %zu align %zu\n", n, (std::size_t) a); return aligned(n, (std::size_t) a); }
void operator delete(void *p, std::align_val_t a) noexcept { std::printf("delete align %zu\n", (std::size_t) a); std::free(p); }
void operator delete(void *p, std::size_t, std::align_val_t a) noexcept { std::printf("delete align %zu\n", (std::size_t) a); std::free(p); }
void *operator new[](std::size_t n, std::align_val_t a) { std::printf("new[] align %zu\n", (std::size_t) a); return aligned(n, (std::size_t) a); }
void operator delete[](void *p, std::align_val_t a) noexcept { std::printf("delete[] align %zu\n", (std::size_t) a); std::free(p); }
void operator delete[](void *p, std::size_t, std::align_val_t a) noexcept { std::printf("delete[] align %zu\n", (std::size_t) a); std::free(p); }
struct alignas(64) V { float f[4]; };
struct alignas(32) W { int k; ~W() {} };
int main() {
  V *v = new V;
  std::printf("%d\n", (int) ((std::size_t) v % 64));
  delete v;
  W *w = new W[3];
  std::printf("%d\n", (int) ((std::size_t) w % 32));
  delete[] w;
  int *i = new int(4);
  std::printf("%d\n", *i);
  delete i;
  return 0;
}
