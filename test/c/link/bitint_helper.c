/* bitint_helper.c -- built by clang: each function of bitint.h that the main calls, and calls of the main's own (1.6.57) */
#include <stdarg.h>
#include "bitint.h"
B48 h48(B48 a, int k) { return a * k - 1; }
U63 h63(U63 a) { return a / 3 + 1; }
B65 h65(B65 a, B65 b) { return a - b; }
B100 h100(long a, long b, long c, long d, long e, B100 v, long f) { return v + a + b + c + d + e + f + m65(1, 2, 3, 4, 5, (B65) v); }
U127 h127(int k, U127 v) { return v * (unsigned) k; }
B128 h128(long a, long b, long c, long d, long e, B128 v) { return v - a - b - c - d - e; }
B100 hcall(B100 (*f)(B100, int), B100 v) { return f(v, 7) + m100(v, 2); }
B48 r48(long k) { return k; }
B65 r65(int k) { return k; }
long hva(int n, ...) {
  va_list ap; va_start(ap, n); long s = 0;
  for (int i = 0; i < n; i++) { B48 a = va_arg(ap, B48); B100 b = va_arg(ap, B100); s += (long) a + (long) (b >> 40); }
  va_end(ap); return s;
}
#if defined(__x86_64__)
long hvb(int n, ...) {
  va_list ap; va_start(ap, n); long s = 0;
  for (int i = 0; i < n; i++) { B129 a = va_arg(ap, B129); U63 b = va_arg(ap, U63); s += (long) (a >> 100) + (long) b; }
  va_end(ap); return s;
}
B129 h129(B129 a, long k) { return a * k; }
U200 r200(long k) { return k; }
U200 h200(int k, U200 a, U200 b) { return a * b + (unsigned) k + m200(a, 3); }
B256 h256(B256 a, long b, long c, long d, long e, long f, B256 g) { return a - g + b + c + d + e + f; }
#endif
