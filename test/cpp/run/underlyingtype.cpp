// std::underlying_type of enums (0.117, __underlying_type): the fixed base when one is written, else int when an enumerator is negative and unsigned
// otherwise ([dcl.enum]/5); sizes and signedness are the clang++ ones
#include <cstdio>
#include <type_traits>
enum E1 { a1, b1 };
enum E2 { a2 = -1, b2 };
enum class E3 : short { a3 };
enum class E4 { a4 };
enum E5 : unsigned char { a5 };
int main() {
  std::underlying_type<E1>::type v1 = 3000000000u;
  std::underlying_type<E2>::type v2 = -5;
  std::underlying_type<E3>::type v3 = -7;
  std::underlying_type_t<E4> v4 = -9;
  std::underlying_type_t<E5> v5 = 255;
  std::printf("%u %d %d %d %d\n", v1, v2, v3, v4, v5);
  std::printf("%d %d %d %d %d\n", (int)sizeof(v1), (int)std::is_unsigned<decltype(v1)>::value, (int)sizeof(v3), (int)sizeof(v4), (int)sizeof(v5));
  return 0;
}
