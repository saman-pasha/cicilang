// An ISO mode (-std=c++20, 0.214): __STRICT_ANSI__ is predefined, and `linux', `unix' and g++'s __GLIBCXX_TYPE_INT_N_0
// are not; `typeof' is a name of the program's, not GNU's keyword. glibc still declares POSIX's names, under the
// _GNU_SOURCE that clang++ predefines on Linux, and <cfloat> has C17's names before C++26
#include <cfloat>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
int typeof = 4;
int linux = 6, unix = 7;
static int twice(int typeof) { return typeof * 2; }
int main() {
#ifdef __STRICT_ANSI__
  std::printf("strict %d\n", __STRICT_ANSI__);
#else
  std::printf("not strict\n");
#endif
#ifdef __GLIBCXX_TYPE_INT_N_0
  std::printf("g++'s int128 name\n");
#endif
  char *d = strdup("posix");
  std::string s = d;
  std::free(d);
  std::printf("%s %d %d %d %d\n", s.c_str(), typeof, linux, unix, twice(typeof));
#if defined(FLT_NORM_MAX) || defined(FLT_SNAN)
  std::printf("C23's float.h\n");
#else
  std::printf("C17's float.h\n");
#endif
  return 0;
}
