#include <cstdio>
#include <cuchar>
#include <cwchar>
// <cuchar>: the C library's conversions of char16_t and char32_t through std (cwrap.cpp's until 0.251). Its .needs skips
// a Mac: Apple's C library has no <uchar.h> (libc++'s own <uchar.h> test fails there by its XFAIL, and the C fixture
// cwrap.c needs __has_include(<uchar.h>)), so std::mbrtoc16 is no name there -- libc++ declares it
// _LIBCPP_USING_IF_EXISTS, and clang++ refuses the call as cicilang++ does
int main() {
  char16_t c16;
  std::mbstate_t st{};
  std::size_t n = std::mbrtoc16(&c16, "A", 1, &st);
  std::printf("%zu %d\n", n, (int) c16);
  char out[8];
  std::mbstate_t st2{};
  std::size_t k = std::c32rtomb(out, U'Z', &st2);
  std::printf("%zu %c\n", k, out[0]);
  char32_t c32;
  std::mbstate_t st3{};
  std::size_t m = std::mbrtoc32(&c32, "B", 1, &st3);
  char out2[8];
  std::mbstate_t st4{};
  std::size_t j = std::c16rtomb(out2, u'C', &st4);
  std::printf("%zu %d %zu %c\n", m, (int) c32, j, out2[0]);
  return 0;
}
