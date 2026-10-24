#include <array>
#include <cstdio>
#include <deque>
#include <functional>
#include <list>
#include <map>
#include <memory>
#include <optional>
#include <set>
#include <string>
#include <tuple>
#include <utility>
#include <vector>
// C++17's deduction guides of the standard library (P0433): containers from a braced list, from iterators and by copy;
// pair, tuple, optional, array, function from a function and a lambda, shared_ptr from a unique_ptr, string from iterators
static int twice(int x) { return 2 * x; }
template <class T> struct Wrap : std::vector<T> { using std::vector<T>::vector; };
int main() {
  std::vector v{1, 2, 3};
  std::vector w{v};
  std::vector it(v.begin(), v.end());
  std::list l{1.5, 2.5};
  std::deque d{'a', 'b', 'c'};
  std::set s{3, 1, 2};
  std::map m{std::pair{1, 'x'}, std::pair{2, 'y'}};
  std::pair p{1, 2.5};
  std::tuple t{1, 'c', 3.5};
  std::optional o{7};
  std::array a{1, 2, 3, 4};
  std::function f{twice};
  std::function g{[](int x) { return x + 1; }};
  std::shared_ptr sp{std::make_unique<int>(9)};
  std::string str{"hello"};
  std::basic_string sub(str.begin() + 1, str.end());
  auto e = std::vector{4, 5};
  std::printf("%zu %zu %zu %zu %zu %zu %zu\n", v.size(), w.size(), it.size(), l.size(), d.size(), s.size(), m.size());
  std::printf("%d %.1f %d %c %.1f %d %zu\n", p.first, p.second, std::get<0>(t), std::get<1>(t), std::get<2>(t), *o, a.size());
  std::printf("%d %d %d %s %zu\n", f(5), g(5), *sp, sub.c_str(), e.size());
  std::printf("%d %d\n", (int) sizeof(decltype(v)::value_type), (int) sizeof(decltype(l)::value_type));
  return 0;
}
