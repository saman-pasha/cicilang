// decltype((E)) of a member access over any object ([dcl.type.decltype]/1.5, [expr.ref]/6.2): by the access's value
// category -- an lvalue `T &', a member of an xvalue or of a prvalue `T &&' -- and a requirement's `{ E } -> C', which is
// C<decltype((E))>; libc++ 23's __value_visitor writes `invoke_result_t<_Visitor &&, decltype((std::forward<_Alts>(
// __alts).__value))...>' (1.6.21: the parentheses were kept only over a chain from a name)
#include <concepts>
#include <utility>
#include <type_traits>
#include <cstdio>
struct alt { double val; };
struct box { alt in; alt make() const { return in; } };
struct cls { double val; cls() : val(1) {} cls(double v) : val(v) {} };
alt fresh() { return alt{1.5}; }
template <class A> auto g2(A &&a) -> decltype((std::forward<A>(a).val)) { return std::forward<A>(a).val; }
template <class A> decltype(auto) g3(A &&a) { return (std::forward<A>(a).val); }
template <class T> concept moved = requires(T t) { { std::move(t).val } -> std::same_as<double &&>; };
template <class T> concept named = requires(T t) { { t.val } -> std::same_as<double &>; };
template <class T> concept made = requires { { T{}.val } -> std::same_as<double &&>; };
#define SAME(E, T) (int) std::is_same_v<decltype(E), T>
int main() {
  alt a{2.5};
  const alt c{0.5};
  box b{{4.0}};
  box *p = &b;
  std::printf("%d %d %d %d\n", SAME(g2(a), double &), SAME(g3(a), double &), SAME(g2(std::move(a)), double &&),
              SAME(g2(c), const double &));
  std::printf("%d %d %d %d\n", SAME((std::forward<alt &>(a).val), double &), SAME((std::move(a).val), double &&),
              SAME((std::move(c).val), const double &&), SAME((fresh().val), double &&));
  std::printf("%d %d %d %d\n", SAME((b.in.val), double &), SAME((p->in.val), double &), SAME((b.make().val), double &&),
              SAME((std::move(b).in.val), double &&));
  std::printf("%d %d %d %d\n", SAME((alt{}.val), double &&), SAME((alt{2.0}.val), double &&), SAME((cls().val), double &&),
              SAME((cls(2.0).val), double &&));
  std::printf("%d %d %d\n", SAME(fresh().val, double), SAME(std::move(a).val, double), SAME(p->in, alt));
  std::printf("%d %d %d %d %d\n", (int) moved<alt>, (int) named<alt>, (int) made<alt>, (int) moved<cls>, (int) made<cls>);
  g2(a) += 1; g3(a) += 1;
  double &&r = g2(std::move(a));
  r += 1;
  std::printf("%g\n", a.val);
  return 0;
}
