// a computed #include ([cpp.include]/7): the directive's tokens macro-replaced, a library header's name joined from `<'
// to `>' with a space only where white space stood; the operand of __has_include alike ([cpp.cond]/4); 0.210 lost the
// header's declarations and macros
#define STD(h) <h>
#define VEC STD(vector)
#include VEC
#define LOCAL "ppinclude.h"
#include LOCAL
#include STD(cstdio)
#if __has_include(VEC) && __has_include(STD(map)) && !__has_include(STD(nope)) && __has_include(LOCAL)
#define HAS 1
#else
#define HAS 0
#endif
int main() {
  std::vector<int> v{1, 2, 3};
  std::printf("%zu %d %d %s\n", v.size(), PPINCLUDE_H, HAS, ppinclude_name());
  return 0;
}
