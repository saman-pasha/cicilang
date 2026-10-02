// a requires-expression is a bool value: in a variable template's initializer and in an if constexpr (0.110)
#include <cstdio>
struct V { int size() const { return 3; } };
struct W { };
template <class T> inline constexpr bool has_size = false || requires(T t) { t.size(); };
template <class T> constexpr int kind() { if constexpr (requires(T t) { t.size(); }) return 1; else return 2; }
int main() { std::printf("%d %d %d %d\n", (int) has_size<V>, (int) has_size<W>, kind<V>(), kind<W>()); return 0; }
