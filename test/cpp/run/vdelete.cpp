#include <cstdio>
#include <cstdlib>
#include <locale>
#include <new>
// a delete-expression through a base whose destructor is virtual ([expr.delete]/3, /10, [class.dtor]/16): the dynamic type's
// destructor and the deallocation function its class finds, over the complete object -- through the deleting destructor in the
// table, a later base's through a thunk; `::delete' the global one; a facet the program made deleted by the library
struct B1 { int b1 = 1; virtual ~B1() { std::printf("~B1\n"); } };
struct B2 { int b2 = 2; virtual ~B2() { std::printf("~B2\n"); } };
struct D : B1, B2 {
  long d = 3;
  ~D() override { std::printf("~D\n"); }
  static void *operator new(std::size_t n) { std::printf("D::new %zu\n", n); return std::malloc(n); }
  static void operator delete(void *p, std::size_t n) { std::printf("D::delete %zu\n", n); std::free(p); }
};
struct E : D { long e[2] = {4, 5}; ~E() { std::printf("~E\n"); } };
struct P { virtual ~P() { std::printf("~P\n"); } void operator delete(void *p) { std::printf("P::delete\n"); std::free(p); } };
struct Q : P { ~Q() { std::printf("~Q\n"); } };
static int facets;
struct Comma : std::numpunct<char> {
  explicit Comma(std::size_t refs = 0) : std::numpunct<char>(refs) { ++facets; }
  ~Comma() { std::printf("~Comma\n"); }
  char do_decimal_point() const override { return ','; }
  static void operator delete(void *p) { std::printf("Comma::delete\n"); std::free(p); }
};
int main() {
  B2 *p = new D;
  std::printf("%d\n", p->b2);
  delete p;
  B1 *q = new E;
  delete q;
  P *r = new Q;
  delete r;
  P *s = new Q;
  ::delete s;
  {
    std::locale loc(std::locale::classic(), new Comma);
    std::printf("%c %d\n", std::use_facet<std::numpunct<char>>(loc).decimal_point(), facets);
  }
  std::printf("done\n");
  return 0;
}
