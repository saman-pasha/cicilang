/* C23's __VA_OPT__ and white space in #x: the group's first token takes the white space before __VA_OPT__, and an
   empty group passes it to the next token; clang's and gcc's output */
#include <stdio.h>
#define S(x) #x
#define XS(x) S(x)
#define VO(a, ...) S(a __VA_OPT__(x))
#define VO2(a, ...) S(a __VA_OPT__( x))
#define VO3(a, ...) S(a __VA_OPT__(x)+)
#define VO4(a, ...) S(a+__VA_OPT__(x) y)
#define VO5(a, ...) S([a __VA_OPT__(__VA_ARGS__)])
#define G5(x) a x
#define T2(x, y) S(x y)
int main(void) {
  puts(VO(1, 2));
  puts(VO2(1, 2));
  puts(VO3(1, 2));
  puts(VO3(1));
  puts(VO4(1));
  puts(VO4(1, 2));
  puts(VO5(1,  q r));
  puts(VO5(1));
  puts(XS(G5() b));
  puts(T2(a, G5()+b));
  puts(XS(G5()));
  return 0;
}
