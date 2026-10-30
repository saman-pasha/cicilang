/* a name written with a universal character name keeps that spelling for #x (0.228; [cpp.stringize]/2), as clang has it */
#include <stdio.h>
#include <string.h>
#define S(a) #a
#define X(a) S(a)
#define Y caf\u00e9
#define caf\u00e9x 5
#define Z(caf\u00e9) caf\u00e9 * 2
int caf\u00e9 = 7;
int main(void) {
  const char *s = S(caf\u00e9), *t = X(S(caf\u00e9)), *u = X(S(caf\U000000E9)), *v = X(S(café)), *w = X(X(Y)), *x = S(Y + caf\u00e9);
  const char *k = X(caf\u00e9x), *z = X(Z(caf\u00e9x));
  printf("%s %zu\n", s, strlen(s));
  printf("%s %zu\n", t, strlen(t));
  printf("%s %zu\n", u, strlen(u));
  printf("%s %zu\n", v, strlen(v));
  printf("%s %zu\n", w, strlen(w));
  printf("%s %zu\n", x, strlen(x));
  printf("%s %s %d\n", k, z, Z(caf\u00e9x));
  printf("%d %d %d\n", café, caf\u00e9 + 1, Y + 2);
  return 0;
}
