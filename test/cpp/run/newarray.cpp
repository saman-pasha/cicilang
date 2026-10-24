#include <cstdio>
#include <cstdlib>
#include <new>
// array new-expressions ([expr.new]/9, /15): the array allocation function over the cookie and the elements -- a class's own
// `operator new[]' and its sized `operator delete[]', which a cookie serves even for a class with nothing to destroy --
// a value-initialized array, `new T[0]', `new (std::nothrow) T[n]' with items, and an element's constructor that throws:
// the elements built destroyed, the last first, and the block given back
struct S {
  int v;
  S() : v(1) {}
  static void *operator new[](std::size_t n) { std::printf("S::new[] %zu\n", n); return std::malloc(n); }
  static void operator delete[](void *p, std::size_t n) { std::printf("S::delete[] %zu\n", n); std::free(p); }
};
struct T {
  int v;
  static int made;
  T() : v(++made) { if (made == 3) throw made; }
  ~T() { std::printf("~T %d\n", v); }
  static void *operator new[](std::size_t n) { std::printf("T::new[] %zu\n", n); return std::malloc(n); }
  static void operator delete[](void *p) { std::printf("T::delete[]\n"); std::free(p); }
};
int T::made;
int main() {
  S *s = new S[4];
  std::printf("%d\n", s[3].v);
  delete[] s;
  int *z = new int[5]();
  std::printf("%d\n", z[4]);
  delete[] z;
  int *e = new int[0];
  std::printf("%d\n", e != nullptr);
  delete[] e;
  int *nt = new (std::nothrow) int[3]{7, 8};
  std::printf("%d %d\n", nt[1], nt[2]);
  delete[] nt;
  try { T *t = new T[5]; delete[] t; } catch (int k) { std::printf("caught %d\n", k); }
  return 0;
}
