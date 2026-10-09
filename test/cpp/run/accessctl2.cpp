// access control, more allowed forms (0.117): a static data member initialized by a private static function, a private nested
// type, a private virtual function called through the public one, a protected constructor and static in a derived class, `using' to
// open a base's member under private inheritance, a friend struct and a friend function template, a friend template class,
// a friend operator and function of a counter, and lambdas (nested, generic) in a member function
#include <cstdio>
#include <vector>
class A {
  static int compute() { return 5; }
  static int v;
  int p = 3;
  enum Mode { Off, On };
  typedef int Id;
  Mode m = On;
public:
  struct N { static int get() { return compute() + v; } int rd(A &a) { return a.p + (int)a.m; } };
  int same(const A &o) const { return o.p + this->p + (*this).p; }
  static int viaN() { return N::get(); }
  Id id() const { return (Id)p; }
  virtual ~A() {}
private:
  virtual int hook() { return 11; }
public:
  int callHook() { return hook(); }
};
int A::v = A::compute() * 2;
class B : public A { int hook() override { return 12; } public: int up() { return callHook(); } };
class P { protected: P(int x) : v(x) {} int v; static int sp() { return 1; } };
class Q : public P { public: Q() : P(4) {} int get() { return v + sp(); } static Q make() { Q q; return q; } };
class Pr : private A { public: using A::same; using A::id; int mine() { return same(*this) + id(); } };
struct F;
class G { int g = 6; friend struct F; template <class T> friend int peekg(T &, const G &); public: G() {} };
struct F { static int look(const G &x) { return x.g; } };
template <class T> int peekg(T &, const G &x) { return x.g * 2; }
template <class T> class W { T t; public: W(T x) : t(x) {} template <class U> friend class W; template <class U> T conv(const W<U> &w) { return (T)w.t; } };
class Counter { int n = 0; public: Counter &operator++() { ++n; return *this; } friend int operator+(const Counter &a, int k) { return a.n + k; } friend int total(const Counter &a); };
int total(const Counter &a) { return a.n * 100; }
class Lam { int s = 8; public: int run() { auto f = [this](int k) { return [this, k]() { return s + k; }(); }; return f(2); } int gen() { return [&](auto x) { return s + x; }(3); } };
int main() {
  A a; B b; std::printf("%d %d %d %d\n", a.same(a), A::viaN(), a.id(), b.up());
  A::N n; std::printf("%d\n", n.rd(a));
  Q q = Q::make(); std::printf("%d\n", q.get());
  Pr pr; std::printf("%d %d\n", pr.mine(), pr.id());
  G g; std::printf("%d %d\n", F::look(g), peekg(g, g));
  W<int> wi(3); W<long> wl(4); std::printf("%d\n", (int)wl.conv(wi));
  Counter c; ++c; ++c; std::printf("%d %d\n", c + 5, total(c));
  Lam l; std::printf("%d %d\n", l.run(), l.gen());
  return 0;
}
