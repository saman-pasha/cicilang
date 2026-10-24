#include <cstdio>
// deduction of a pointer to function's parts from a function's name ([temp.deduct.call]/2: a function argument
// decays to a pointer for a by-value parameter of pointer type), a function template and a class template's guide
static int twice(int x) { return 2 * x; }
static double half(double x, int) { return x / 2; }
template <class R, class... A> int arity(R (*)(A...)) { return (int) sizeof...(A); }
template <class R, class A> R apply(R (*f)(A), A a) { return f(a); }
template <class F> struct Fn;
template <class R, class... A> struct Fn<R(A...)> {
  R (*p)(A...);
  Fn(R (*q)(A...)) : p(q) {}
  R operator()(A... a) const { return p(a...); }
};
template <class R, class... A> Fn(R (*)(A...)) -> Fn<R(A...)>;
int main() {
  Fn f{twice};
  Fn g(half);
  std::printf("%d %d %d %d %.2f\n", arity(twice), arity(half), apply(twice, 4), f(5), g(3.0, 1));
  return 0;
}
