// names that two headers' reads declare in two namespaces, named bare inside a namespace whose item is not the first header's
// (0.219): <charconv> gives `__traits' first (std::__itoa's) and <string> `__base' (std::__variant_detail's), so <variant>'s
// unqualified `__traits<_Types...>' and <functional>'s `__base<_Rp(_ArgTypes...)>' must find their own namespaces'
#include <charconv>
#include <string>
#include <variant>
#include <functional>
#include <cstdio>
int main() {
  std::variant<int> one = 4;
  std::variant<int, std::string> two = std::string("ab");
  std::function<int(int)> f = [](int x) { return x * 5; };
  int n = 0;
  const char *s = "17";
  std::from_chars(s, s + 2, n);
  std::printf("%d %s %d %d %d\n", std::get<0>(one), std::get<1>(two).c_str(), f(3), n, (int)two.index());
  return 0;
}
