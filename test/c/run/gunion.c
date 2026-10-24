#include <stdio.h>
#include <string.h>
/* a union's constant has the type of the member given, and the struct or the array that holds it follows (C 6.7.9/17):
   unions in struct globals, in arrays, nested, and a static table of tagged unions */
union U { char c; int i; long long l; double d; const char *s; };
struct S { char x; union U u; char y; };
struct T { int k; struct S s; union U v[2]; };
struct Tok { int kind; union { int i; double d; const char *s; } v; };
static struct S g1 = { 1, { .i = 5 }, 2 };
static struct S g2 = { 3, { .l = 7 }, 4 };
static struct S g3[2] = { { 5, { .c = 6 }, 7 }, { 8, { .l = 9 }, 10 } };
static union U ga[3] = { { .c = 'a' }, { .i = 12 }, { .d = 2.5 } };
static struct T gt = { 11, { 12, { .d = 1.25 }, 13 }, { { .s = "str" }, { .i = 14 } } };
static const struct Tok toks[] = { { 1, { .i = 42 } }, { 2, { .d = 3.5 } }, { 3, { .s = "name" } } };
int main(void) {
  printf("%d %d %d %d %lld %d\n", g1.x, g1.u.i, g1.y, g2.x, g2.u.l, g2.y);
  printf("%d %d %d %d %lld %d\n", g3[0].x, g3[0].u.c, g3[0].y, g3[1].x, g3[1].u.l, g3[1].y);
  printf("%c %d %g %zu\n", ga[0].c, ga[1].i, ga[2].d, sizeof ga);
  printf("%d %d %g %d %s %d %zu\n", gt.k, gt.s.x, gt.s.u.d, gt.s.y, gt.v[0].s, gt.v[1].i, sizeof gt);
  for (size_t n = 0; n < sizeof toks / sizeof toks[0]; n++) {
    if (toks[n].kind == 1) printf("int %d\n", toks[n].v.i);
    else if (toks[n].kind == 2) printf("double %g\n", toks[n].v.d);
    else printf("name %s\n", toks[n].v.s);
  }
  unsigned char raw[sizeof g1]; memcpy(raw, &g1, sizeof g1);
  printf("%d %d %d %d\n", raw[0], raw[8], raw[12], raw[16]);
  return 0;
}
