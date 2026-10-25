// libc++ 21's C++23 facilities by their feature-test macros (0.206): ranges::contains, contains_subrange, starts_with,
// ends_with, find_last, iota and the folds, the containers' ranges members and from_range constructors, bind_back,
// out_ptr and inout_ptr, and is_implicit_lifetime.
#include <algorithm>
#include <cstdio>
#include <deque>
#include <functional>
#include <list>
#include <memory>
#include <numeric>
#include <ranges>
#include <set>
#include <string>
#include <type_traits>
#include <vector>

struct Agg { int a; double b; };
struct NotImplicit { NotImplicit(const NotImplicit &) {} ~NotImplicit() {} };

struct NoDelete { void operator()(int *) const noexcept {} };
static int slot_a = 77, slot_b = 0;
static int c_api_make(int **out) { *out = &slot_a; return 0; }
static int c_api_bump(int **inout) { slot_b = **inout + 1; *inout = &slot_b; return 0; }

int main() {
  std::vector<int> v{3, 1, 4, 1, 5, 9, 2, 6};
  std::printf("contains %d %d\n", (int) std::ranges::contains(v, 5), (int) std::ranges::contains(v, 7));
  std::vector<int> sub{1, 5, 9};
  std::printf("contains_subrange %d\n", (int) std::ranges::contains_subrange(v, sub));
  std::printf("starts_ends %d %d\n", (int) std::ranges::starts_with(v, std::vector<int>{3, 1}), (int) std::ranges::ends_with(v, std::vector<int>{2, 6}));
  auto fl = std::ranges::find_last(v, 1);
  std::printf("find_last %td %zu\n", fl.begin() - v.begin(), fl.size());
  std::vector<int> io(4);
  std::ranges::iota(io, 10);
  std::printf("iota %d %d\n", io.front(), io.back());
  std::printf("fold %d %d\n", std::ranges::fold_left(v, 0, std::plus<>{}), std::ranges::fold_left_with_iter(sub, 1, std::multiplies<>{}).value);
  std::vector<int> w{1, 2};
  w.append_range(std::vector<int>{3, 4});
  w.insert_range(w.begin(), std::list<int>{0});
  std::deque<int> dq(std::from_range, std::views::iota(0, 3));
  std::set<int> se(std::from_range, v);
  std::string s;
  s.assign_range(std::string_view("abc"));
  s.append_range(std::vector<char>{'d', 'e'});
  std::printf("containers %zu %d %zu %zu %s\n", w.size(), w[0], dq.size(), se.size(), s.c_str());
  auto sub10 = std::bind_back(std::minus<>{}, 10);
  std::printf("bind_back %d\n", sub10(25));
  std::unique_ptr<int, NoDelete> up;
  c_api_make(std::out_ptr(up));
  int first = *up;
  c_api_bump(std::inout_ptr(up));
  std::printf("out_ptr %d %d\n", first, *up);
  std::printf("implicit_lifetime %d %d %d\n", (int) std::is_implicit_lifetime_v<Agg>, (int) std::is_implicit_lifetime_v<int[3]>,
              (int) std::is_implicit_lifetime_v<NotImplicit>);
}
