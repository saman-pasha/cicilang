// A STATIC ASSERTION OVER A CONSTANT OBJECT'S MEMBER FOLDS (0.257): `q.a + q.b == 7' over `constexpr Q q{3, 4}', a pair's
// members, a member call, a library container's size, a trait, a constexpr call and a lambda -- each passes as clang++
// takes it, where a condition that does not fold is refused. The member with no call was asked of the evaluator only where
// the condition held a call, and passed unasked.
#include <array>
#include <cstdio>
#include <string_view>
#include <type_traits>
#include <utility>
struct Q { int a, b; };
struct P { int v; constexpr int get() const { return v; } };
constexpr Q q{3, 4};
constexpr P p{5};
constexpr std::pair<int, int> pr{1, 2};
constexpr std::array<int, 3> arr{1, 2, 3};
constexpr std::string_view sv = "abc";
constexpr int sq(int x) { return x * x; }
constexpr auto inc = [](int x) { return x + 1; };
static_assert(q.a + q.b == 7, "members");
static_assert(pr.first == 1 && pr.second == 2);
static_assert(p.get() == 5 && arr.size() == 3 && sv.size() == 3);
static_assert(std::is_same_v<int, int> && sq(7) == 49 && inc(1) == 2);
template <class T> struct W { static_assert(sizeof(T) >= 1, "complete"); T t; };
int main() {
  constexpr int k = 4;
  static_assert(k * 2 == 8);
  W<int> w{q.a + pr.second};
  std::printf("%d %d %d %zu\n", w.t, p.get(), sq(k), sv.size());
  return 0;
}
