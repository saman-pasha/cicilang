#include <stdio.h>
/* a universal character name in a macro's name is the character it names (C17 6.4.3, 6.4.2.1): `caf\u00e9' and `café'
   are one macro, in #define, #ifdef, #ifndef, #undef and a parameter's name; 0.212 read `caf' as the macro's name */
#define caf\u00e9 3
#define TWICE(x\u00e9) (x\u00e9 * 2)
#define café_plus 1
int main(void) {
#ifdef café
  printf("%d %d", café, caf\u00e9);
#endif
#ifndef caf\u00e9
  printf(" no");
#endif
  printf(" %d %d\n", TWICE(5), café_plus);
#undef caf\u00e9
#ifdef café
  printf("still\n");
#else
  printf("gone\n");
#endif
  return 0;
}
