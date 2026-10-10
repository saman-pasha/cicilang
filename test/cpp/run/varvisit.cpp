// std::variant, FIRST SURFACE (0.121): the converting constructor and assignment (`std::variant<int, double> v = 7;'), std::visit with a function
// object and with a generic lambda, std::get, index, holds_alternative. libc++ 18's variant is built on a union template per alternative count,
// classes of one name in two namespaces (`__access::__base', `__visitation::__base'), an overload set made of a pack of bases
// (`__all_overloads : _Bases... { using _Bases::operator()...; }'), a local class in `__assign_alt' and a table of function pointers made by a
// constexpr function.
#include <variant>
#include <cstdio>
struct Printer {
  void operator()(int i) const { std::printf("int %d\n", i); }
  void operator()(double d) const { std::printf("double %.2f\n", d); }
};
int main() {
  std::variant<int, double> v = 7;
  std::visit(Printer(), v);
  v = 2.5;
  std::visit(Printer(), v);
  int r = std::visit([](auto x) -> int { return (int) (x * 2); }, v);
  std::printf("%d %zu %d\n", r, v.index(), std::holds_alternative<double>(v) ? 1 : 0);
  std::printf("%d\n", (int) std::get<double>(v));
  std::variant<int, double> w(std::in_place_index<1>, 4.5);
  std::printf("%zu %.1f\n", w.index(), std::get<1>(w));
  w.emplace<0>(9);
  std::printf("%zu %d\n", w.index(), std::get<0>(w));
  return 0;
}
