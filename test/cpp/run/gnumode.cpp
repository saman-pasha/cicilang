// A GNU mode (no -std: gnu++17, 0.214): `linux', `unix' and g++'s __GLIBCXX_TYPE_INT_N_0 are predefined and
// __STRICT_ANSI__ is not, and `typeof' is GNU's keyword; `asm' is the label's in every C++ mode, and <cfloat> has C17's
// names before C++26 in this mode too
#include <cfloat>
#include <cstdio>
int gm_seven() asm("gm_impl");
extern "C" int gm_impl() { return 7; }
int main() {
  int a = 5;
  typeof(a) b = a + 1;
  __GLIBCXX_TYPE_INT_N_0 w = (__GLIBCXX_TYPE_INT_N_0) 1 << 100;
#ifdef __STRICT_ANSI__
  std::printf("strict\n");
#else
  std::printf("gnu %d %d %d %d %d\n", linux, unix, __GLIBCXX_BITSIZE_INT_N_0, b, gm_seven());
#endif
  std::printf("%d\n", (int) (w >> 99));
#ifdef FLT_SNAN
  std::printf("signaling NaNs\n");
#else
  std::printf("no signaling NaNs\n");
#endif
  return 0;
}
