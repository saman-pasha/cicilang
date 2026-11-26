// std::visit over generic lambdas: a written result, a deduced one and none, over a variant and a const one; libc++ 23's
// __value_visitor results in invoke_result_t<_Visitor &&, decltype((std::forward<_Alts>(__alts).__value))...> (1.6.21)
#include <variant>
#include <cstdio>
int main() {
  std::variant<int, double> v = 2.5;
  double d = std::visit([](auto &x) -> double { return x * 2; }, v);
  const std::variant<int, double> c = 3;
  int k = std::visit([](auto &x) { return (int) x + 1; }, c);
  std::visit([](auto &x) { ++x; }, v);
  std::printf("%g %d %g\n", d, k, std::get<double>(v));
  return 0;
}
