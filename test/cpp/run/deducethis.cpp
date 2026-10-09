// C++23's deducing this ([dcl.fct]/6) on a class's methods: the explicit object parameter's type is deduced from the object
// the call is made on -- `this auto &&self', `template <class Self> ... this Self &&self' -- so one function serves the const
// and the non-const object, the lvalue and the prvalue, and the DERIVED class, which is the CRTP's replacement.
#include <cstdio>
#include <string>
#include <utility>
struct Node {
  int v;
  template <class Self> int get(this Self &&self) { return self.v; }
  int get2(this auto &&self) { return self.v + 1; }
  auto twice(this const Node &self) { return self.v * 2; }
  int add(this Node &self, int n) { self.v += n; return self.v; }
  int byval(this Node self) { self.v += 100; return self.v; }
  auto sum(this auto &&self, int k) { return self.v + k; }
};
struct Derived : Node { int w; };
struct Base {
  void run(this auto &&self) { self.step(); self.step(); }
  int total(this auto &&self) { return self.count * 10; }
};
struct Impl : Base {
  int count = 0;
  void step() { count++; std::printf("step %d\n", count); }
};
struct Box {
  int v = 4;
  int fact(this auto &&self, int n) { return n < 2 ? 1 : n * self.fact(n - 1); }
  template <class Self> int fwd(this Self &&self) { return std::forward<Self>(self).v; }
  int operator()(this auto &&self, int k) { return self.v * k; }
  int operator[](this const Box &self, int i) { return self.v + i; }
  bool operator==(this const Box &a, const Box &b) { return a.v == b.v; }
  Box &operator+=(this Box &self, int n) { self.v += n; return self; }
  std::string name(this auto const &self) { return "box" + std::to_string(self.v); }
};
Box make() { Box b; b.v = 6; return b; }
struct Chain {
  int n = 0;
  Chain &inc(this Chain &self) { self.n++; return self; }
  int get(this auto &&self) { return self.n; }
};
int main() {
  Node n{3};
  std::printf("%d %d %d\n", n.get(), n.get2(), n.twice());
  std::printf("%d %d\n", n.add(4), n.byval());
  const Node c{5};
  std::printf("%d %d\n", c.get(), c.get2());
  Derived d; d.v = 9; d.w = 1;
  std::printf("%d %d\n", d.get(), d.get2());
  std::printf("%d\n", n.sum(10));
  Impl i;
  i.run();
  std::printf("%d\n", i.total());
  Node *p = &n;
  std::printf("%d\n", p->get());
  Box b;
  std::printf("%d %d\n", b.fact(5), b.fwd());
  std::printf("%d %d %d\n", b(3), b[2], (int)(b == make()));
  b += 3;
  std::printf("%d %s\n", b.v, b.name().c_str());
  std::printf("%d %d\n", make().fact(4), make().fwd());
  Chain ch;
  ch.inc().inc().inc();
  std::printf("%d\n", ch.get());
  return 0;
}
