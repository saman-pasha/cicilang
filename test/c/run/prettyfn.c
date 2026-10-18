/* __func__, __FUNCTION__ and __PRETTY_FUNCTION__ in C: clang's signature, `(void)' for a prototype of no parameter */
#include <stdio.h>
#include <stddef.h>
#define P() printf("%s | %s | %s\n", __func__, __FUNCTION__, __PRETTY_FUNCTION__)
struct point { int x, y; };
typedef unsigned long ulong_t;
static int add(int a, const char *s, ...) { P(); (void) s; return a; }
void kinds(struct point *p, unsigned u, long long ll, const char **pp, int (*fn)(int), double d[3], char *argv[], _Bool b, size_t n, ulong_t w, unsigned char uc, long double ld, short sh) { P(); (void) p; (void) u; (void) ll; (void) pp; (void) fn; (void) d; (void) argv; (void) b; (void) n; (void) w; (void) uc; (void) ld; (void) sh; }
int old() { P(); return 0; }
struct point *mk(void) { P(); return NULL; }
const char *const *cc(const int *const q) { P(); (void) q; return NULL; }
int main(void) {
  P();
  add(1, "x");
  kinds(NULL, 0, 0, NULL, NULL, NULL, NULL, 0, 0, 0, 0, 0, 0);
  old(); mk(); cc(NULL);
  return 0;
}
