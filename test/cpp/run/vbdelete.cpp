#include <cstdio>
#include <cstdlib>
#include <new>
// a delete-expression through a VIRTUAL base whose destructor is virtual: the most derived class's deleting destructor,
// through the virtual base's table, its own class-specific operator delete over the complete object
struct V { int v = 1; virtual ~V() { std::printf("~V\n"); } };
struct A : virtual V { int a = 2; ~A() { std::printf("~A\n"); } };
struct D : A {
  long d = 3;
  ~D() { std::printf("~D\n"); }
  static void *operator new(std::size_t n) { std::printf("D::new %zu\n", n); return std::malloc(n); }
  static void operator delete(void *p, std::size_t n) { std::printf("D::delete %zu\n", n); std::free(p); }
};
int main() {
  V *p = new D;
  std::printf("%d\n", p->v);
  delete p;
  A *q = new D;
  delete q;
  return 0;
}
