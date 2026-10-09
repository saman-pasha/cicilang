// std::variant (0.121, C++17), taken whole in two fixtures: this one -- construction from a value and in place, assignment between alternatives,
// copy and move of a variant holding a long string (the string of the source survives a COPY and is moved out of a MOVED-from variant), swap,
// emplace, the relational operators, std::visit with the `overloaded' idiom and with two variants, get_if, a vector of variants.
#include <variant>
#include <string>
#include <vector>
#include <cstdio>
template <class... Ts> struct overloaded : Ts... { using Ts::operator()...; };
template <class... Ts> overloaded(Ts...) -> overloaded<Ts...>;
struct Pt { int x, y; };
int main() {
  std::variant<int, std::string> v = 3;
  std::printf("%zu %d\n", v.index(), std::get<int>(v));
  v = std::string("abc");
  std::printf("%zu %s\n", v.index(), std::get<std::string>(v).c_str());
  std::visit(overloaded{ [](int i) { std::printf("int %d\n", i); }, [](const std::string &s) { std::printf("string %s\n", s.c_str()); } }, v);
  v = 42;
  std::visit(overloaded{ [](int i) { std::printf("int %d\n", i); }, [](const std::string &s) { std::printf("string %s\n", s.c_str()); } }, v);
  if (auto *p = std::get_if<int>(&v)) std::printf("get_if int %d\n", *p);
  if (auto *p = std::get_if<std::string>(&v)) std::printf("get_if string %s\n", p->c_str()); else std::printf("not a string\n");
  std::printf("%zu\n", std::variant_size_v<decltype(v)>);

  std::variant<std::monostate, int, double, std::string> a;
  std::printf("%zu\n", a.index());
  a = 5;
  std::variant<std::monostate, int, double, std::string> b = a;
  std::printf("%zu %d\n", b.index(), std::get<int>(b));
  b = std::string("hello world, a longer string to leave the small buffer");
  std::variant<std::monostate, int, double, std::string> copy = b;
  std::printf("%zu %s | %s\n", copy.index(), std::get<std::string>(copy).c_str(), std::get<std::string>(b).c_str());
  std::variant<std::monostate, int, double, std::string> c = std::move(b);
  std::printf("%zu %s\n", c.index(), std::get<std::string>(c).c_str());
  c.emplace<double>(2.5);
  std::printf("%zu %.1f\n", c.index(), std::get<double>(c));
  a.swap(c);
  std::printf("%zu %zu\n", a.index(), c.index());

  std::variant<int, double> x = 1, y = 2, z = 2.0;
  std::printf("%d %d %d %d\n", (int) (x < y), (int) (x == y), (int) (y == z), (int) (y != z));
  auto sum = std::visit([](auto p, auto q) { return (double) p + (double) q; }, x, z);
  std::printf("%.1f\n", sum);
  std::variant<Pt, std::vector<int>> pv = Pt{3, 4};
  std::printf("%d\n", std::get<Pt>(pv).x + std::get<Pt>(pv).y);
  pv = std::vector<int>{1, 2, 3};
  std::printf("%zu\n", std::get<std::vector<int>>(pv).size());
  std::variant<int, long> w = 5L;
  std::printf("%zu\n", w.index());

  std::vector<std::variant<int, std::string>> items;
  items.push_back(1);
  items.push_back(std::string("two"));
  items.push_back(3);
  int total = 0; size_t chars = 0;
  for (const auto &it : items) {
    std::visit([&](const auto &q) {
      using T = std::decay_t<decltype(q)>;
      if constexpr (std::is_same_v<T, int>) total += q; else chars += q.size();
    }, it);
  }
  std::printf("%d %zu\n", total, chars);
  return 0;
}
