// a function template's deduced results: decltype(auto), auto &, auto && and auto, each beside a plain function's;
// an instance's decltype(auto) is its first return's decltype ([dcl.type.auto.deduct]/5), where it was a decayed auto (1.6.21)
#include <utility>
#include <type_traits>
#include <cstdio>
struct alt { double val; };
template <class A> decltype(auto) t1(A &&a) { return (std::forward<A>(a).val); }
template <class A> decltype(auto) t2(A &&a) { return std::forward<A>(a).val; }
template <class A> decltype(auto) t3(A &&a) { return std::forward<A>(a); }
template <class A> auto &t4(A &a) { return a.val; }
template <class A> auto &&t5(A &&a) { return std::forward<A>(a).val; }
template <class A> auto t6(A &a) { return a.val; }
decltype(auto) p1(alt &a) { return (a.val); }
auto &p4(alt &a) { return a.val; }
#define SAME(E, T) (int) std::is_same_v<decltype(E), T>
int main() {
  alt a{1.0};
  std::printf("%d %d %d %d\n", SAME(t1(a), double &), SAME(t1(std::move(a)), double &&), SAME(t2(a), double),
              SAME(t3(a), alt &));
  std::printf("%d %d %d %d\n", SAME(t3(std::move(a)), alt &&), SAME(t4(a), double &), SAME(t5(a), double &),
              SAME(t5(std::move(a)), double &&));
  std::printf("%d %d %d\n", SAME(t6(a), double), SAME(p1(a), double &), SAME(p4(a), double &));
  t1(a) += 1; t3(a).val += 1; t4(a) += 1; t5(a) += 1; p1(a) += 1; p4(a) += 1;
  std::printf("%g\n", a.val);
  return 0;
}
