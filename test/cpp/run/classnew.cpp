#include <cstdio>
#include <cstdlib>
#include <new>
// class-specific allocation and deallocation functions ([class.free]): static members whether or not they are declared
// so, found by the new-expression's and the delete-expression's lookup in the class, inherited by a derived class, the
// dynamic type's chosen through a virtual destructor, and `::new' and `::delete' bypassing them
struct A {
  int v;
  A(int k) : v(k) {}
  static void *operator new(std::size_t n) { std::printf("A::new %zu\n", n); return std::malloc(n); }
  void operator delete(void *p) { std::printf("A::delete\n"); std::free(p); }
  void *operator new[](std::size_t n) { std::printf("A::new[] %d\n", n > 0); return std::malloc(n); }
  void operator delete[](void *p) { std::printf("A::delete[]\n"); std::free(p); }
};
struct B : A { int w; B() : A(1), w(2) {} };
struct P {
  virtual ~P() { std::printf("~P\n"); }
  void operator delete(void *p) { std::printf("P::delete\n"); std::free(p); }
};
struct Q : P {
  long x[3];
  ~Q() override { std::printf("~Q\n"); }
  void operator delete(void *p) { std::printf("Q::delete\n"); std::free(p); }
};
int main() {
  A *a = new A(7);
  std::printf("%d\n", a->v);
  delete a;
  B *b = new B;
  std::printf("%d %d\n", b->v, b->w);
  delete b;
  A *as = new A[2]{A(1), A(2)};
  std::printf("%d\n", as[1].v);
  delete[] as;
  A *g = ::new A(9);
  std::printf("%d\n", g->v);
  ::delete g;
  P *p = new Q;
  delete p;
  return 0;
}
