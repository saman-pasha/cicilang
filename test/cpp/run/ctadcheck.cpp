// Class template argument deduction and explicit template arguments: a guide whose result does not substitute is no
// candidate, a deduced specialization satisfies its template's constraints or the deduction fails (a requirement
// unmet), a template's bare name binds only a template template parameter, and a type's name only a type parameter.
#include <concepts>
#include <cstdio>
#include <vector>
template <std::integral T> struct OnlyInt {
  T v;
  OnlyInt(T x) : v(x) {}
};
template <class X> concept MakesOnlyInt = requires(X x) { OnlyInt{x}; };
template <class T> struct Holder {
  T v;
};
template <class T> Holder(T) -> Holder<typename T::value_type>;
template <class T> Holder(T *) -> Holder<T *>;
template <template <class...> class C> int pick() { return 2; }
template <class T> int pick() { return 3; }
template <template <class...> class C, class R> auto remake(const R &r) { return C(r.begin(), r.end()); }
int main() {
  int i = 5;
  std::printf("%d %d %d\n", (int) MakesOnlyInt<int>, (int) MakesOnlyInt<double>, (int) MakesOnlyInt<long>);
  Holder h{&i};
  std::printf("%d\n", *h.v);
  std::printf("%d %d\n", pick<std::vector>(), pick<int>());
  std::vector<int> a{4, 5, 6};
  auto b = remake<std::vector>(a);
  std::printf("%d %d\n", (int) b.size(), b[2]);
  return 0;
}
