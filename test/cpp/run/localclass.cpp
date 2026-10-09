// LOCAL CLASSES (0.121; [class.local]): a class defined in a function body -- named or not -- with member functions, constructors,
// virtual functions and bases is a class of the unit under a name of its own, registered where the walk meets it. libc++ 18's
// std::variant assigns an alternative through an UNNAMED local class (`struct { void operator()(true_type) const ...; ... } __impl{this, ...}').
// Two functions' `Loc' are two classes; a local class is a template argument; a lambda's body may define one.
#include <cstdio>
#include <vector>
int first() {
  struct Loc {
    int v;
    Loc(int x) : v(x * 2) { std::printf("ctor %d\n", v); }
    ~Loc() { std::printf("dtor %d\n", v); }
    int get() const { return v; }
  };
  Loc a(3);
  Loc b(4);
  return a.get() + b.get();
}
int second() {
  struct Loc {          // another class of the same name
    double d;
    double half() const { return d / 2; }
  };
  Loc l{5.0};
  return (int) l.half();
}
struct Shape { virtual int area() const { return 1; } virtual ~Shape() {} };
int third(int k) {
  struct Sq : Shape {
    int s;
    Sq(int s_) : s(s_) {}
    int area() const override { return s * s; }
  };
  struct Rect : Shape {
    int w, h;
    Rect(int w_, int h_) : w(w_), h(h_) {}
    int area() const override { return w * h; }
  };
  Sq q(k);
  Rect r(k, k + 1);
  const Shape &a = q;
  const Shape &b = r;
  return a.area() + b.area();
}
int fourth() {
  struct P { int x, y; int sum() const { return x + y; } };
  std::vector<P> v;
  v.push_back(P{1, 2});
  v.push_back(P{3, 4});
  int t = 0;
  for (const P &p : v) t += p.sum();
  auto f = [](int n) { struct Dbl { int m; int twice() const { return m * 2; } }; return Dbl{n}.twice(); };
  return t + f(10);
}
int fifth() {
  int total = 0;
  struct {
    int base;
    int *out;
    void operator()(int x) const { *out = x + base; }
    void operator()(long x) const { *out = (int) x * 2 + base; }
  } impl{10, &total};
  impl(5);
  int a = total;
  impl(7L);
  return a * 100 + total;
}
template <class A> int sixth(A &&arg, int k) {
  int out = 0;
  struct {
    void operator()(int x) const { *res = x + 1; }
    void operator()(long x) const { *res = (int) x * 2 + arg; }
    int *res;
    A &&arg;
  } impl{&out, static_cast<A &&>(arg)};
  if (k) impl(5); else impl(7L);
  return out;
}
int main() {
  int v = 100;
  std::printf("%d %d %d %d\n", first(), second(), third(3), fourth());
  std::printf("%d %d %d %d\n", fifth(), sixth(v, 1), sixth(v, 0), sixth(50, 0));
  return 0;
}
