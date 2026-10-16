/* Bitfields past 60 bits, stored and in a global's constant: a 64-bit field, fields of 61 to 63 bits beside a small
   one, a signed 64-bit field, a 100-bit unsigned __int128 field, and a global's field at bit 61 and above (0.155) */
#include <stdio.h>
struct A { unsigned long long a : 64; };
struct B { unsigned long long a : 63, b : 1; };
struct C { unsigned long long a : 62, b : 2; };
struct D { unsigned long long a : 61, b : 3; };
struct E { long long a : 64; };
struct F { unsigned __int128 a : 100, b : 28; };
struct G { unsigned char c : 3; unsigned long long a : 60, b : 1; };
struct H { int x : 5, y : 7; unsigned z : 20; };
struct S { unsigned long long a : 61, b : 3; };
struct A ga = { 0xFEDCBA9876543210ULL };
struct B gb = { 0x7FFFFFFFFFFFFFF0ULL, 1 };
struct D gd = { 0x1FFFFFFFFFFFFFF2ULL, 5 };
struct E ge = { -3 };
struct F gf = { ((unsigned __int128) 0xF0F0F0F0FULL << 64) | 0x0123456789ABCDEFULL, 0xABCDEF };
struct G gg = { 5, 0x0FFFFFFFFFFFFFFFULL, 1 };
struct H gh = { -3, 21, 0xABCDE };
struct S gs = { 5, 7 };
int main(void) {
  struct A x = {0}; struct B y = {0, 0}; struct C z = {0, 0}; struct D w = {0, 0}; struct E e = {0}; struct F f = {0, 0};
  x.a = 0xFEDCBA9876543210ULL;
  y.b = 1; y.a = 0x7FFFFFFFFFFFFFF0ULL;
  z.b = 3; z.a = 0x3FFFFFFFFFFFFFF1ULL;
  w.b = 5; w.a = 0x1FFFFFFFFFFFFFF2ULL;
  e.a = -3;
  f.b = 0xABCDEF; f.a = ((unsigned __int128) 0xF0F0F0F0FULL << 64) | 0x0123456789ABCDEFULL;
  printf("A %llx\n", (unsigned long long) x.a);
  printf("B %llx %llx\n", (unsigned long long) y.a, (unsigned long long) y.b);
  printf("C %llx %llx\n", (unsigned long long) z.a, (unsigned long long) z.b);
  printf("D %llx %llx\n", (unsigned long long) w.a, (unsigned long long) w.b);
  printf("E %lld\n", (long long) e.a);
  printf("F %llx %llx %llx\n", (unsigned long long) (f.a >> 64), (unsigned long long) f.a, (unsigned long long) f.b);
  y.a += 1; printf("B2 %llx %llx\n", (unsigned long long) y.a, (unsigned long long) y.b);
  f.b = 7; f.a = ~(unsigned __int128) 0; f.a -= 1;
  printf("F2 %llx %llx %llx\n", (unsigned long long) (f.a >> 64), (unsigned long long) f.a, (unsigned long long) f.b);
  e.a = -9223372036854775807LL - 1; printf("E2 %lld\n", (long long) e.a); e.a += 5; printf("E3 %lld\n", (long long) e.a);
  struct G g = { 0 }; g.c = 6; g.a = 0x0EDCBA9876543210ULL; g.b = 1; g.a += 3;
  printf("G %x %llx %x\n", (unsigned) g.c, (unsigned long long) g.a, (unsigned) g.b);
  printf("gA %llx\n", (unsigned long long) ga.a);
  printf("gB %llx %llx\n", (unsigned long long) gb.a, (unsigned long long) gb.b);
  printf("gD %llx %llx\n", (unsigned long long) gd.a, (unsigned long long) gd.b);
  printf("gE %lld\n", (long long) ge.a);
  printf("gF %llx %llx %llx\n", (unsigned long long) (gf.a >> 64), (unsigned long long) gf.a, (unsigned long long) gf.b);
  printf("gG %x %llx %x\n", (unsigned) gg.c, (unsigned long long) gg.a, (unsigned) gg.b);
  printf("gH %d %d %x\n", gh.x, gh.y, (unsigned) gh.z);
  printf("gS %llx %llx\n", (unsigned long long) gs.a, (unsigned long long) gs.b);
  return 0;
}
