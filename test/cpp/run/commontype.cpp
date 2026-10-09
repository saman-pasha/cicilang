// std::common_type of one, two and several arithmetic types. libc++ 21 writes it on clang's `__builtin_common_type' where the compiler has it
// (`__has_builtin'), and on the specializations libc++ 18 has where it has not; this compiler answers 0 for the builtin, and the
// specializations run (0.126). stdnumeric, stdptrcmp and the atomic fixtures ask for it through <numeric>, <memory> and <atomic>.
#include <cstdio>
#include <type_traits>
#include <utility>
template <class T, class U, class = void> struct has_common : std::false_type {};
template <class T, class U> struct has_common<T, U, std::void_t<std::common_type_t<T, U>>> : std::true_type {};
int main() {
  std::printf("%d %d %d %d\n", (int) std::is_same_v<std::common_type_t<int, long>, long>,
              (int) std::is_same_v<std::common_type_t<int, double, float>, double>, (int) std::is_same_v<std::common_type_t<char>, char>,
              (int) std::is_same_v<std::common_type_t<const int, volatile int>, int>);
  std::printf("%d %d %d %d\n", (int) std::is_same_v<std::common_type_t<short, unsigned short>, int>,
              (int) std::is_same_v<std::common_type_t<float, int>, float>, (int) std::is_same_v<std::common_type_t<char, long long>, long long>,
              (int) std::is_same_v<std::common_type_t<const int &, double>, double>);
  std::printf("%d %d\n", (int) has_common<int, double>::value, (int) has_common<long, unsigned char>::value);
  std::printf("%d %d\n", (int) sizeof(std::common_type_t<int, long>), (int) sizeof(std::common_type_t<char, short>));
  return 0;
}
