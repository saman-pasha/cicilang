/* The standard's EXAMPLE 4 of macro replacement (C17 6.10.3.5/5), its lines printed through #x: `#' and `##' together,
   a header's name made by pastes, a paste giving a macro's name, and a name its own expansion left unexpanded beside
   a paste; clang's and gcc's output */
#include <stdio.h>
#define S_(...) #__VA_ARGS__
#define XS(...) S_(__VA_ARGS__)
#define str(s) # s
#define xstr(s) str(s)
#define debug(s, t) printf("x" # s "= %d, x" # t "= %s", \
 x ## s, x ## t)
#define INCFILE(n) vers ## n
#define glue(a, b) a ## b
#define xglue(a, b) glue(a, b)
#define HIGHLOW "hello"
#define LOW LOW ", world"
int main(void) {
  puts(XS(debug(1, 2);));
  puts(str(: @\n));
  puts(xstr(INCFILE(2).h));
  puts(XS(glue(HIGH, LOW);));
  puts(XS(xglue(HIGH, LOW)));
  return 0;
}
