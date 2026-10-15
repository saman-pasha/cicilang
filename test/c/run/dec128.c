/* a decimal floating value to and from a 128-bit integer (0.137): libgcc has no such routine; cicilang puts its own
   (module/bidrt.c) into the module. The expectation is gcc's build of the same program over those helpers, the values
   checked against Python's decimal module. */
#include <stdio.h>
#include <string.h>
typedef unsigned __int128 u128;
static void pint(__int128 x) { char t[64]; int i = 0; u128 v = x < 0 ? -(u128) x : (u128) x; if (!v) t[i++] = '0';
  while (v) { t[i++] = '0' + (int) (v % 10); v /= 10; } if (x < 0) putchar('-'); while (i) putchar(t[--i]); }
static void puint(u128 v) { char t[64]; int i = 0; if (!v) t[i++] = '0'; while (v) { t[i++] = '0' + (int) (v % 10); v /= 10; } while (i) putchar(t[--i]); }
static _Decimal32 i_sd(__int128 x) { return (_Decimal32) x; }     /*conv*/
static _Decimal64 i_dd(__int128 x) { return x; }                  /*conv*/
static _Decimal128 i_td(__int128 x) { return (_Decimal128) x; }   /*conv*/
static _Decimal64 u_dd(u128 x) { return (_Decimal64) x; }         /*conv*/
static _Decimal128 u_td(u128 x) { _Decimal128 d = x; return d; }  /*conv*/
static __int128 sd_i(_Decimal32 d) { return (__int128) d; }       /*conv*/
static __int128 dd_i(_Decimal64 d) { __int128 x = d; return x; }  /*conv*/
static __int128 td_i(_Decimal128 d) { return (__int128) d; }      /*conv*/
static u128 td_u(_Decimal128 d) { return (u128) d; }              /*conv*/
int main(void) {
  __int128 xs[] = { 0, 1, -1, 9999999, 10000000, 12345675, 12345685, (__int128) 1234566500000000000ll * 10 + 1,
    (__int128) 1 << 100, -((__int128) 1 << 120), (__int128) 0x7fffffffffffffffll * 1000000000000000000ll + 123456789,
    (__int128) ((((u128) 1) << 127) - 1), -(__int128) ((((u128) 1) << 127) - 1) - 1 };
  for (unsigned i = 0; i < sizeof xs / sizeof xs[0]; i++) {
    _Decimal32 s = i_sd(xs[i]); _Decimal64 d = i_dd(xs[i]); _Decimal128 t = i_td(xs[i]);
    unsigned sh; unsigned long dh, th[2]; memcpy(&sh, &s, 4); memcpy(&dh, &d, 8); memcpy(th, &t, 16);
    pint(xs[i]); printf(" %08x %016lx %016lx%016lx", sh, dh, th[1], th[0]);
    printf(" | "); if (i < 11) pint(sd_i(s)); else printf("-"); printf(" "); pint(dd_i(d)); printf(" "); pint(td_i(t)); printf("\n");
  }
  u128 big = ~(u128) 0; _Decimal64 ud = u_dd(big); _Decimal128 ut = u_td(big); unsigned long uh, uth[2];
  memcpy(&uh, &ud, 8); memcpy(uth, &ut, 16); puint(big); printf(" %016lx %016lx%016lx ", uh, uth[1], uth[0]); puint(td_u(ut)); printf("\n");
  _Decimal128 ds[] = { 1.9DL, -1.9DL, 123456789012345678901234567890.75DL, -1.7e38DL, 0.000001DL, 1234567890123456789012345678901234e4DL };
  for (unsigned i = 0; i < sizeof ds / sizeof ds[0]; i++) { pint(td_i(ds[i])); printf(" "); } printf("\n");
  pint(dd_i(-9.999999999999999e37DD)); printf(" "); pint(sd_i(-1234567e30DF)); printf(" "); pint(dd_i(7.5DD)); printf("\n");
  return 0;
}
