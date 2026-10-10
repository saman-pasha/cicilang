// A constructor defined OUT OF ITS CLASS (0.133): a default one, one with member initializers, one of a class with a
// destructor, and a nested class's, by its qualified name, beside its destructor -- each was dropped, and the link
// named a symbol nothing defined.
#include <cstdio>
#include <string>
struct P {
  int v;
  P();
  P(int k);
};
P::P() { v = 3; }
P::P(int k) : v(k) {}
struct R {
  int w;
  R();
  ~R() { std::printf("drop r %d\n", w); }
};
R::R() { w = 4; }
struct Outer {
  struct Inner {
    int z;
    std::string s;
    Inner();
    ~Inner();
  };
  Inner in;
  int k;
  Outer(int a);
};
Outer::Inner::Inner() : z(5), s("inner") { std::printf("make inner\n"); }
Outer::Inner::~Inner() { std::printf("drop inner %s\n", s.c_str()); }
Outer::Outer(int a) : k(a) { std::printf("make outer %d %d\n", k, in.z); }
int main() {
  P p;
  P q(7);
  R r;
  Outer o(9);
  std::printf("%d %d %d %s %d\n", p.v, q.v, r.w, o.in.s.c_str(), o.k);
  return 0;
}
