/* A bitfield in a union is the low bits of the union's first bytes: read masked, written without touching the
   other bits, signed or unsigned by its type; a designated initializer names a member of an anonymous union (0.112) */
#include <stdio.h>
struct Std { unsigned char al : 3; _Bool f : 1; unsigned char t; };
struct Chr { unsigned char al : 3; _Bool g : 1; unsigned char u; };
struct Parsed {
  union {
    unsigned char al : 3;
    struct Std std_;
    struct Chr chr_;
  };
  int width;
  int prec;
};
union U { unsigned char raw; int sb : 3; unsigned ub : 5; };
struct Parsed make(int w) {
  return (struct Parsed){.std_ = (struct Std){.al = 1, .f = 1, .t = 7}, .width = w, .prec = 3};
}
int main(void) {
  struct Parsed p = make(5);
  printf("%d %d %d %d %d %d\n", (int) p.std_.al, (int) p.std_.f, p.std_.t, p.width, p.prec, (int) p.al);
  struct Parsed q = {.chr_ = {.al = 2, .g = 1, .u = 9}, .width = 1, .prec = 2};
  printf("%d %d %d %d\n", (int) q.chr_.al, q.chr_.u, q.width, (int) q.al);
  q.al = 5;
  printf("%d %d %d\n", (int) q.al, (int) q.chr_.g, (int) q.chr_.al);
  union U u;
  u.raw = 0xAB;
  printf("%d %d\n", u.sb, (int) u.ub);
  u.sb = -2;
  printf("%d %d %d\n", u.sb, u.raw, (int) u.ub);
  u.ub = 17;
  printf("%d %d\n", u.raw, u.sb);
  return 0;
}
