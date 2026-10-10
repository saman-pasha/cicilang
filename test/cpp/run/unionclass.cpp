// A UNION AT NAMESPACE SCOPE WITH A CONSTRUCTOR, A DESTRUCTOR OR A METHOD IS A CLASS (0.121): the reader keeps it `union(N, Ms)', which the
// lowering took for a plain union and refused at its first use. It goes a class's whole road over the storage of a union -- constructors, a
// method, `new', a copy, a member of another class, an aggregate initializer that names the first member, a namespace.
#include <cstdio>
union V {
  int i;
  float f;
  int twice() const { return i * 2; }
  static int zero() { return 0; }
};
union W {
  int i;
  char c[4];
  W() : i(0) {}
  W(int x) : i(x) {}
  int low() const { return c[0]; }
};
namespace ns {
union X { long l; double d; X(long v) : l(v) {} long get() const { return l; } };
}
struct Holder { W w; int tag; Holder(int a) : w(a), tag(1) {} };
int main() {
  V v; v.i = 21;
  std::printf("%d\n", v.twice());
  V v2 = {5};
  std::printf("%d %d\n", v2.i, V::zero());
  W w(0x01020304);
  std::printf("%d %d\n", w.low(), w.i);
  W w0;
  std::printf("%d\n", w0.i);
  ns::X x(77);
  std::printf("%ld\n", x.get());
  W *p = new W(9);
  std::printf("%d\n", p->i);
  delete p;
  Holder h(12);
  std::printf("%d %d\n", h.w.i, h.tag);
  W copy = w;
  std::printf("%d\n", copy.i);
  return 0;
}
