// a call through a temporary function object whose operator() fits nothing is taken out where its type is asked (0.221):
// the call inside a functional cast, as libc++'s `strong_ordering(compare_three_way()(t, u))' is, by a constraint and a concept
#include <cstdio>
struct R { int v; R(int x) : v(x) {} };
struct F { template <class T> requires (sizeof(T) > 4) int operator()(T) const { return 1; } };
template <class T> concept HasLess = requires(T a, T b) { a < b; };
struct C { template <class T> requires HasLess<T> int operator()(T a, T b) const { return a < b; } };
struct NoLess { int v; };
template <class T> auto pick(T t, int) -> decltype(R(F()(t))) { return R(F()(t)); }
template <class T> R pick(T, long) { return R(2); }
template <class T> auto pick2(T a, T b, int) -> decltype(R(C()(a, b))) { return R(C()(a, b)); }
template <class T> R pick2(T, T, long) { return R(7); }
int main() {
  std::printf("%d %d %d %d\n", pick(1.0, 0).v, pick('c', 0).v, pick2(1, 2, 0).v, pick2(NoLess{1}, NoLess{2}, 0).v);
  return 0;
}
