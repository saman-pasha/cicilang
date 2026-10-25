// libc++'s C++17 facilities by their feature-test macros (0.206): exchange, as_const, make_from_tuple, launder, the
// three-argument hypot, sample (its tag dispatch takes the nearer base), the three searchers, the traits the compiler
// answers, shared_timed_mutex's locks, a transparent comparator's lookup, uncaught_exceptions, the interference sizes,
// void_t, the logical traits, is_invocable, is_nothrow_swappable (a declaration's noexcept merged), bool_constant,
// not_fn, clamp, gcd and lcm.
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <exception>
#include <functional>
#include <iterator>
#include <map>
#include <mutex>
#include <new>
#include <numeric>
#include <random>
#include <shared_mutex>
#include <string>
#include <tuple>
#include <type_traits>
#include <utility>
#include <vector>

struct P { int x; double y; };
struct Q { Q(int a, int b) : s(a + b) {} int s; };
struct NA { NA(int) {} };
struct Pad { char c; int i; };

int main() {
  int a = 1; int old = std::exchange(a, 5);
  std::printf("exchange %d %d\n", old, a);
  std::vector<int> v{3, 1, 2};
  const auto &cv = std::as_const(v);
  std::printf("as_const %zu %d\n", cv.size(), (int) std::is_const_v<std::remove_reference_t<decltype(cv)>>);
  Q q = std::make_from_tuple<Q>(std::make_tuple(4, 5));
  std::printf("make_from_tuple %d\n", q.s);
  alignas(int) unsigned char buf[sizeof(int)];
  ::new (buf) int(42);
  std::printf("launder %d\n", *std::launder(reinterpret_cast<int *>(buf)));
  std::printf("hypot %.1f\n", std::hypot(2.0, 3.0, 6.0));
  std::vector<int> pop{1, 2, 3, 4, 5, 6, 7, 8, 9, 10}, out;
  std::mt19937 g(1);
  std::sample(pop.begin(), pop.end(), std::back_inserter(out), 3, g);
  std::printf("sample");
  for (int x : out) std::printf(" %d", x);
  std::printf("\n");
  std::string hay = "the quick brown fox jumps", needle = "brown";
  auto i1 = std::search(hay.begin(), hay.end(), std::default_searcher(needle.begin(), needle.end()));
  auto i2 = std::search(hay.begin(), hay.end(), std::boyer_moore_searcher(needle.begin(), needle.end()));
  auto i3 = std::search(hay.begin(), hay.end(), std::boyer_moore_horspool_searcher(needle.begin(), needle.end()));
  std::printf("searchers %td %td %td\n", i1 - hay.begin(), i2 - hay.begin(), i3 - hay.begin());
  std::printf("traits %d %d %d %d %d\n", (int) std::has_unique_object_representations_v<int>,
              (int) std::has_unique_object_representations_v<float>, (int) std::has_unique_object_representations_v<Pad>,
              (int) std::is_aggregate_v<P>, (int) std::is_aggregate_v<NA>);
  std::shared_timed_mutex m;
  { std::shared_lock<std::shared_timed_mutex> l(m); std::printf("shared %d\n", (int) l.owns_lock()); }
  { std::unique_lock<std::shared_timed_mutex> l(m); std::printf("unique %d\n", (int) l.owns_lock()); }
  std::map<std::string, int, std::less<>> mp{{"one", 1}, {"two", 2}};
  std::printf("lookup %d %zu\n", mp.find("two")->second, mp.count("three"));
  std::printf("uncaught %d\n", std::uncaught_exceptions());
  std::printf("interference %zu %zu\n", std::hardware_destructive_interference_size, std::hardware_constructive_interference_size);
  std::printf("void_t %d\n", (int) std::is_same_v<std::void_t<int, P>, void>);
  std::printf("conjunction %d %d %d\n", (int) std::conjunction_v<std::true_type, std::is_integral<int>>,
              (int) std::disjunction_v<std::false_type, std::is_floating_point<int>>, (int) std::negation_v<std::false_type>);
  std::printf("invocable %d %d\n", (int) std::is_invocable_v<int (*)(int), int>, (int) std::is_invocable_r_v<long, int (*)(int), int>);
  std::printf("swappable %d %d\n", (int) std::is_swappable_v<int>, (int) std::is_nothrow_swappable_v<std::string>);
  std::printf("bool_constant %d\n", (int) std::bool_constant<true>::value);
  std::printf("not_fn %d\n", (int) std::not_fn([](int x) { return x > 2; })(1));
  std::printf("clamp %d\n", std::clamp(15, 0, 10));
  std::printf("gcd %d lcm %d\n", std::gcd(12, 18), std::lcm(4, 6));
}
