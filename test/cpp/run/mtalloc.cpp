#include <cstdio>
#include <cstdlib>
#include <new>
// a class's allocation function written as a member template: a placement form over a pack
struct A {
  int v = 4;
  template <class... Ts> static void *operator new(std::size_t n, Ts... ts) { std::printf("A::new %d %d\n", (int) (n > 0), (int) sizeof...(ts)); return std::malloc(n); }
  static void operator delete(void *p) { std::printf("A::delete\n"); std::free(p); }
};
int main() {
  A *a = new (1, 2) A;
  std::printf("%d\n", a->v);
  delete a;
  return 0;
}
