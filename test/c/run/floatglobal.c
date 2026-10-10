/* FLOATING VALUES AND WIDE INTEGERS IN A GLOBAL'S INITIALIZER (0.129). A floating constant under a cast to an integer type is
   part of an integer constant expression (C 6.6/6), and the engine's 61-bit integers do not hold 1e30: `(__int128) 1e30' was
   refused (global_init), `int g = 2.5;' spelled a double's hex for an i32, `(double) (int) 2.5' passed over the cast, and
   `(double) ((__int128) 1 << 100)' kept an integer for a double. */
#include <stdio.h>

int g1 = 2.5;
int g2 = -2.5;
_Bool g3 = 0.5;
long g4 = (long)1e18;
long long g5 = -9.2e18;
double g6 = (double)(int)2.5;
double g7 = (double)((__int128)1 << 100);
float g8 = (float)((unsigned __int128)1 << 100);
__int128 g9 = (__int128)1e30;
unsigned __int128 g10 = 3e38;
__int128 g11 = -(__int128)12345.75;
__int128 g12 = (__int128)-1e20 / 7;
double g13 = (double)~0ULL;
unsigned long g14 = (unsigned long)1.8e19;
enum { E1 = (int)7.9, E2 = (int)-7.9 };
int arr[(int)3.99];

int main(void) {
  printf("%d %d %d %ld %lld\n", g1, g2, (int)g3, g4, g5);
  printf("%g %g %g\n", g6, g7, (double)g8);
  printf("%llx %llx\n", (unsigned long long)(g9 >> 64), (unsigned long long)g9);
  printf("%llx %llx\n", (unsigned long long)(g10 >> 64), (unsigned long long)g10);
  printf("%lld %lld\n", (long long)g11, (long long)g12);
  printf("%.17g %lu %d %d %zu\n", g13, g14, E1, E2, sizeof arr / sizeof arr[0]);
  return 0;
}
