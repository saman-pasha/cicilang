// std::variant at C++20 (0.121): the alternative chosen for a converting constructor, where a conversion that narrows is no candidate
// (`variant<std::string, bool> v = "text";' holds the string -- libc++ 18's `__check_for_narrowing'), and std::visit<R> with an explicit result type.
#include <variant>
#include <string>
#include <cstdio>
template <class... Ts> struct overloaded : Ts... { using Ts::operator()...; };
template <class... Ts> overloaded(Ts...) -> overloaded<Ts...>;
int main() {
  std::variant<std::string, bool> a = "text";
  std::variant<bool, std::string> b = "text";
  std::variant<int, double> c = 2.5;
  std::variant<int, double> d = 7;
  std::variant<float, double> e = 1.5f;
  std::variant<float, double> f = 1.5;
  std::variant<long, double> g = 3L;
  std::variant<bool, int> h = 3;
  std::variant<int, bool> i = true;
  std::variant<char, int> j = 'x';
  std::variant<long, int> k = 5;
  std::variant<int, std::string> l = std::string("s");
  std::printf("%zu %zu %zu %zu %zu %zu %zu %zu %zu %zu %zu %zu\n", a.index(), b.index(), c.index(), d.index(), e.index(), f.index(), g.index(), h.index(), i.index(), j.index(), k.index(), l.index());
  std::variant<int, std::string> p = 2, q = std::string("x");
  double r = std::visit<double>(overloaded{ [](int n) { return n * 1.5; }, [](const std::string &s) { return (double) s.size(); } }, p);
  std::printf("%.1f\n", r);
  std::variant<std::monostate, int> m;
  std::printf("%zu %d\n", m.index(), (int) (m == std::variant<std::monostate, int>{}));
  auto idx = [](const auto &v) { return v.index(); };
  std::printf("%zu %zu\n", idx(p), idx(q));
  return 0;
}
