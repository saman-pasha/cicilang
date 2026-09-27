#include <cstdio>
template <class T> struct Ctx { T a, b; };
template <class C>
struct Holder {
  constexpr Holder(C v) : v_{v} { use(Parse<C>{v_, 1}, Ctx2{v_, 2}); }
  static int use(Parse<C> p, Ctx2 c) { return p.a + c.b; }
  int get() const { return v_ + Ctx2{1, 2}.b + Alias{3, 4}.a; }
private:
  C v_;
  template <class U> using Parse = Ctx<U>;
  using Ctx2 = Ctx<C>;
  typedef Ctx<C> Alias;
};
int main() { Holder<int> h(5); std::printf("%d\n", h.get()); return 0; }
