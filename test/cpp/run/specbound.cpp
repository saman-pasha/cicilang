#include <cstdio>
#include <cstddef>
#include <type_traits>
template <class T> struct S { static constexpr int n = 0; };
template <class T, std::size_t N> struct S<T[N]> { static constexpr auto n = N; };
template <class T, std::size_t N> constexpr auto len(T (&)[N]) { return N; }
template <class T> struct V;
template <class T, long N> struct V<T[N]> { static constexpr auto n = N; };
int main() {
  int a[5];
  std::printf("%d %d\n", (int) std::is_same_v<decltype(S<int[7]>::n), const std::size_t>, (int) S<int[7]>::n);
  std::printf("%d %d\n", (int) std::is_same_v<decltype(len(a)), std::size_t>, (int) len(a));
  std::printf("%d %ld\n", (int) std::is_same_v<decltype(V<char[3]>::n), const long>, (long) V<char[3]>::n);
  std::printf("%d\n", (int) sizeof(S<int[7]>::n));
  return 0;
}
