// std::variant (0.121, C++17), the second fixture: std::in_place_type, emplace by index, variant_size_v and variant_alternative_t, std::hash of a variant
// (a generic lambda whose block typedefs name `decltype(__alt)' and a class bound to a path), a visit of two variants, a class whose copy
// constructor counts, and the alternative the converting constructor chooses -- by the conversion that is no narrowing one, and the exact
// match before a conversion (`variant<long, int> v = 5;' holds the int).
#include <variant>
#include <string>
#include <functional>
#include <cstdio>
struct Counter { int n; Counter(int x) : n(x) {} Counter(const Counter &o) : n(o.n + 100) {} };
int main() {
  std::variant<int, double, std::string> v(std::in_place_type<std::string>, "typed");
  std::printf("%zu %s\n", v.index(), std::get<2>(v).c_str());
  v.emplace<0>(42);
  std::printf("%zu %d %d\n", v.index(), std::get<0>(v), (int) std::holds_alternative<int>(v));
  using V = std::variant<char, long, double>;
  std::printf("%zu %d %d\n", std::variant_size_v<V>, (int) std::is_same_v<std::variant_alternative_t<1, V>, long>, (int) std::is_same_v<std::variant_alternative_t<2, V>, double>);
  std::variant<int, std::string> x = 5, y = std::string("a"), z = 5;
  std::printf("%d %d %d %d\n", (int) (x == z), (int) (x != y), (int) (x < y), (int) (y > x));
  std::hash<std::variant<int, std::string>> h;
  std::printf("%d %d\n", (int) (h(x) == h(z)), (int) (h(x) != h(y)));
  auto r = std::visit([](auto a, auto b) -> int { return (int) sizeof(a) + (int) sizeof(b); }, std::variant<char, int>('c'), std::variant<short, long>(2L));
  std::printf("%d\n", r);
  std::variant<Counter, int> c = Counter(1);
  std::variant<Counter, int> d = c;
  std::printf("%d %d\n", std::get<0>(c).n, std::get<0>(d).n);
  std::variant<std::string, bool> a1 = "text";
  std::variant<bool, std::string> b1 = "text";
  std::variant<int, double> c1 = 2.5;
  std::variant<int, double> d1 = 7;
  std::variant<float, double> e1 = 1.5f;
  std::variant<float, double> f1 = 1.5;
  std::variant<long, double> g1 = 3L;
  std::variant<bool, int> h1 = 3;
  std::variant<int, bool> i1 = true;
  std::variant<char, int> j1 = 'x';
  std::variant<long, int> k1 = 5;
  std::variant<int, std::string> l1 = std::string("s");
  std::printf("%zu %zu %zu %zu %zu %zu %zu %zu %zu %zu %zu %zu\n", a1.index(), b1.index(), c1.index(), d1.index(), e1.index(), f1.index(), g1.index(), h1.index(), i1.index(), j1.index(), k1.index(), l1.index());
  return 0;
}
