// A free function template's trailing requires-clause joins its head's (0.199): the overload whose constraint fails is no candidate
#include <cstdio>
template <class T> int f(T) requires (sizeof(T) > 4) { return 1; }
template <class T> int f(T) requires (sizeof(T) <= 4) { return 2; }
template <class T> struct S { int g() requires (sizeof(T) > 4) { return 3; } int g() requires (sizeof(T) <= 4) { return 4; } };
template <class T> int h(T) requires (sizeof(T) > 100);
template <class T> int h(T) { return 5; }
template <class T> concept Small = sizeof(T) <= 4;
template <class T> int k(T) requires Small<T> { return 6; }
template <class T> int k(T) { return 7; }
int main() { std::printf("%d %d %d %d %d %d %d\n", f(1), f(1.0), S<int>{}.g(), S<double>{}.g(), h(1), k(1), k(1.0)); }
