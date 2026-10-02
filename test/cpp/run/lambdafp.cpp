// A captureless lambda converts to a pointer to function (0.112): declared, passed, assigned, and as a member set in a
// constructor template's initializer -- the shape of libc++'s <format> output buffer
#include <cstddef>
#include <cstdio>
int apply(int (*f)(int), int x) { return f(x); }
struct Buf {
  void (*flush)(int *, std::size_t, void *);
  int k;
  template <class T> Buf(T *) : flush([](int *a, std::size_t n, void *o) { a[0] = (int) n + *static_cast<T *>(o); }), k(1) {}
};
int main() {
  int (*g)(int) = [](int x) { return x * 3; };
  std::printf("%d %d\n", g(4), apply([](int x) { return x + 1; }, 9));
  auto lam = [](int a, int b) { return a - b; };
  int (*h)(int, int) = lam;
  int (*k)(int, int);
  k = lam;
  std::printf("%d %d\n", h(10, 4), k(3, 8));
  int arr[2] = {0, 0};
  int base = 100;
  Buf b(&base);
  b.flush(arr, 42, &base);
  std::printf("%d %d\n", arr[0], b.k);
  void (*pv)() = [] { std::printf("void\n"); };
  pv();
  return 0;
}
