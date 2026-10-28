// a class argument converted at a call through an object's operator() (0.221): a local object, a static member function and a
// reference cast as the argument -- `h(s)' over `int operator()(V) const', with `S::operator V()', stored the S as a V, since the
// road of a local object's call took no argument pass (cpp_ref_args_of)
#include <cstdio>
struct V { int n; };
struct S { int n; operator V() const { return V{n * 2}; } };
struct H {
  int operator()(V v) const { return v.n; }
  int f(V v) const { return v.n + 1; }
  static int g(V v) { return v.n + 2; }
};
int main() {
  S s{21};
  const S &cs = s;
  H h;
  std::printf("%d %d %d\n", h(s), h(cs), h(static_cast<const S &>(s)));
  std::printf("%d %d %d\n", h.f(static_cast<const S &>(s)), h.f(static_cast<S &&>(s)), H::g(static_cast<const S &>(s)));
}
