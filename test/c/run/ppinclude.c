#include <stdio.h>
/* a computed #include (C17 6.10.2/4, its EXAMPLE 2 in 6.10.2/8): the directive's tokens macro-replaced, a header name
   joined from `<' to `>' with a space only where white space stood; the operand of __has_include and __has_embed and
   the name of #embed alike (C23 6.10.1/4, 6.10.4); 0.210 lost the header's declarations and macros */
#define VERSION 2
#if VERSION == 1
#define INCFILE "vers1.h"
#elif VERSION == 2
#define INCFILE "ppinclude.h"
#else
#define INCFILE "versN.h"
#endif
#include INCFILE
#define STD(h) <h>
#include STD(stdint.h)
#define SYS <limits.h>
#include SYS
#if __has_include(INCFILE) && __has_include(STD(stddef.h)) && !__has_include(STD(nope.h)) && __has_embed(INCFILE) == __STDC_EMBED_FOUND__
#define HAS 1
#else
#define HAS 0
#endif
static const char head[] = {
#embed INCFILE limit(12)
  , 0 };
int main(void) {
  int8_t x = INT8_MAX;
  ppinclude_pair p = { 3, 4 };
  printf("%d %d %d %d %d %d\n", PPINCLUDE_H, x, CHAR_BIT, HAS, p.a * p.b, PPINCLUDE_K);
  printf("[%s]\n", head);
  return 0;
}
