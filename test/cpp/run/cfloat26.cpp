// C++26's <cfloat> is C23's <float.h> (P3348R4, [cfloat.syn]): __STDC_VERSION_FLOAT_H__, INFINITY and NAN, and the
// signaling NaNs, beside the names C17 gave (0.214); C++20's has none of them, in either mode
#include <cfloat>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <limits>
static int quiet_bit(float f) { unsigned u; std::memcpy(&u, &f, sizeof u); return (u >> 22) & 1; }
static int quiet_bit(double d) { unsigned long long u; std::memcpy(&u, &d, sizeof u); return (u >> 51) & 1; }
int main() {
  std::printf("%ld\n", (long) __STDC_VERSION_FLOAT_H__);
  float f = FLT_SNAN;
  double d = DBL_SNAN;
  long double l = LDBL_SNAN;
  std::printf("%d %d %d\n", std::isnan(f), std::isnan(d), std::isnan(l));
  std::printf("%d %d\n", quiet_bit(f), quiet_bit(d));
  std::printf("%d %d\n", quiet_bit(std::numeric_limits<float>::signaling_NaN()), quiet_bit(std::numeric_limits<float>::quiet_NaN()));
  float inf = INFINITY, nan = NAN;
  std::printf("%d %d %d\n", inf > FLT_MAX, nan != nan, std::isinf(inf));
  std::printf("%d %d\n", FLT_DECIMAL_DIG, DBL_DECIMAL_DIG);
  return 0;
}
