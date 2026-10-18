// the steps of libc++'s tuple formatter's compile-time parse, one consteval function each (0.168): a tuple element through
// std::get (a cast to a base's reference), a lambda that captures by reference (a reference member read through), a
// function pointer member called, string_view members set
#include <cstdio>
#include <tuple>
#include <utility>
#include <string_view>
struct P { int v = 0; constexpr void parse() { v += 5; } };
consteval int t1() { std::tuple<P, P> t; std::get<1>(t).parse(); return std::get<1>(t).v; }
template <class F, std::size_t... I> constexpr void each(std::index_sequence<I...>, F f) { (f.template operator()<I>(), ...); }
consteval int t2() { std::tuple<P, P> t; each(std::make_index_sequence<2>(), [&]<std::size_t I> { std::get<I>(t).parse(); }); return std::get<0>(t).v + std::get<1>(t).v; }
struct H { void (*fp)(int &); };
consteval int t3() { H h{[](int &x) { x = 7; }}; int k = 0; h.fp(k); return k; }
struct Q { std::string_view sep = ", ", open = "(", close = ")"; constexpr void set(std::string_view a, std::string_view b) { open = a; close = b; } };
consteval int t4() { Q q; q.set({}, {}); return (int) q.open.size() + (int) q.sep.size(); }
struct R { int &r; constexpr void bump() { r += 3; } };
consteval int t5() { int x = 4; R a{x}; a.bump(); a.r += 1; return x; }
int main() { std::printf("%d %d %d %d %d\n", t1(), t2(), t3(), t4(), t5()); return 0; }
