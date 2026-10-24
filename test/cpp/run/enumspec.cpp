// an enumeration's value template argument in specializations and folds: an explicit and a partial specialization by an
// enumerator, a default argument from a static member, a comparison of the value, `if constexpr' over it, an unscoped enum's
#include <cstdio>
enum class E : int { a, b, c };
enum P { p0, p1 };
template <E V> struct S { static constexpr int v = (V == E::b) ? 10 : 20; };
template <E V> struct T;
template <> struct T<E::b> { static constexpr int w = 7; };
struct Tr { static constexpr E t = E::c; };
template <class X, E V = X::t> struct U;
template <class X> struct U<X, E::a> { static constexpr int u = 1; };
template <class X> struct U<X, E::c> { static constexpr int u = 3; };
template <P Q> struct W { static constexpr int q = Q == p1 ? 5 : 6; };
template <> struct W<p0> { static constexpr int q = 9; };
template <E V> int f() { if constexpr (V == E::a) return 100; else return 200; }
int main() { std::printf("%d %d %d %d %d %d %d\n", S<E::b>::v, S<E::a>::v, T<E::b>::w, U<Tr>::u, W<p1>::q, W<p0>::q, f<E::a>() + f<E::c>()); return 0; }
