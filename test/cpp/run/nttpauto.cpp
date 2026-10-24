// A placeholder parameter (template <auto N>) takes the argument's own type (0.199): a class's static, a variable template, a function's result
#include <cstdio>
#include <type_traits>
template <auto N> struct X { static constexpr auto v = N; };
template <auto N> constexpr auto w = N;
template <auto N> auto get() { return N; }
int main() {
  std::printf("%d %d %d %d\n", (int) std::is_same_v<decltype(X<'a'>::v), const char>, (int) std::is_same_v<decltype(X<5>::v), const int>,
              (int) std::is_same_v<decltype(X<5u>::v), const unsigned>, (int) std::is_same_v<decltype(X<5L>::v), const long>);
  std::printf("%d %d %d\n", (int) std::is_same_v<decltype(w<'b'>), const char>, (int) std::is_same_v<decltype(get<'c'>()), char>, (int) sizeof(X<'a'>::v));
}
