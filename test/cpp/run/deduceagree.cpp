// A template parameter that two function parameters deduce deduces ONE type ([temp.deduct.type]): a candidate whose second argument
// names another type is no candidate, whatever the second argument converts to -- libc++ 21's `operator*(const _Tp &, const
// complex<_Tp> &)' over two complex<double> was a candidate with _Tp = complex<double>, the converting constructor of
// complex<complex<double>> taking the second argument.
#include <cstdio>
#include <type_traits>
#include <utility>

template <class T> struct W {
  T v;
  W(const T &x = T()) : v(x) {}
};
struct B {
  int b;
};
struct A {
  int a;
  A(const B &x = B{0}) : a(x.b) {}
};

template <class T> int f(const T &, const W<T> &) { return 1; }
template <class T> int g(const T &, const T &) { return 2; }
template <class T> int pick(const T &, const W<T> &) { return 3; }
template <class T> int pick(const W<T> &, const W<T> &) { return 4; }

template <class T, class U, class = void> struct can_f : std::false_type {};
template <class T, class U> struct can_f<T, U, std::void_t<decltype(f(std::declval<T>(), std::declval<U>()))>> : std::true_type {};
template <class T, class U, class = void> struct can_g : std::false_type {};
template <class T, class U> struct can_g<T, U, std::void_t<decltype(g(std::declval<T>(), std::declval<U>()))>> : std::true_type {};

int main() {
  std::printf("%d %d %d %d\n", (int) can_f<int, W<int>>::value, (int) can_f<W<int>, W<int>>::value, (int) can_f<double, W<int>>::value,
              (int) can_f<W<int>, W<W<int>>>::value);
  std::printf("%d %d %d\n", (int) can_g<A, A>::value, (int) can_g<A, B>::value, (int) can_g<B, A>::value);
  W<int> w(5);
  W<W<int>> ww(w);
  std::printf("%d %d %d\n", pick(w, w), pick(1, w), pick(w, ww));
  return 0;
}
