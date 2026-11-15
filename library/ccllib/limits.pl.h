/* the C limits and the floating limits that <limits.pl>'s text names (phase 1c). The text is lexed, not preprocessed,
   so a macro of <limits.h> or <float.h> is not a name in it: these small functions carry the macros into C and C++. */
#ifndef _CICILANG_CCLLIB_LIMITS_PL_H
#define _CICILANG_CCLLIB_LIMITS_PL_H
#include <limits.h>
#include <float.h>
#include <math.h>
static inline long long ccllib_limits_smax(int bits) {
    return bits <= 8 ? SCHAR_MAX : bits <= 16 ? SHRT_MAX : bits <= 32 ? INT_MAX : LLONG_MAX;
}
static inline long long ccllib_limits_smin(int bits) {
    return bits <= 8 ? SCHAR_MIN : bits <= 16 ? SHRT_MIN : bits <= 32 ? INT_MIN : LLONG_MIN;
}
static inline unsigned long long ccllib_limits_umax(int bits) {
    return bits <= 8 ? UCHAR_MAX : bits <= 16 ? USHRT_MAX : bits <= 32 ? UINT_MAX : ULLONG_MAX;
}
static inline float ccllib_limits_max_f(void) { return FLT_MAX; }
static inline float ccllib_limits_min_f(void) { return FLT_MIN; }
static inline float ccllib_limits_epsilon_f(void) { return FLT_EPSILON; }
static inline float ccllib_limits_infinity_f(void) { return INFINITY; }
static inline float ccllib_limits_quiet_NaN_f(void) { return NAN; }
static inline double ccllib_limits_max_d(void) { return DBL_MAX; }
static inline double ccllib_limits_min_d(void) { return DBL_MIN; }
static inline double ccllib_limits_epsilon_d(void) { return DBL_EPSILON; }
static inline double ccllib_limits_infinity_d(void) { return INFINITY; }
static inline double ccllib_limits_quiet_NaN_d(void) { return NAN; }
static inline long double ccllib_limits_max_ld(void) { return LDBL_MAX; }
static inline long double ccllib_limits_min_ld(void) { return LDBL_MIN; }
static inline long double ccllib_limits_epsilon_ld(void) { return LDBL_EPSILON; }
static inline long double ccllib_limits_infinity_ld(void) { return INFINITY; }
static inline long double ccllib_limits_quiet_NaN_ld(void) { return NAN; }
static inline int ccllib_limits_digits_f(void) { return FLT_MANT_DIG; }
static inline int ccllib_limits_digits_d(void) { return DBL_MANT_DIG; }
static inline int ccllib_limits_digits_ld(void) { return LDBL_MANT_DIG; }
static inline int ccllib_limits_digits10_f(void) { return FLT_DIG; }
static inline int ccllib_limits_digits10_d(void) { return DBL_DIG; }
static inline int ccllib_limits_digits10_ld(void) { return LDBL_DIG; }
#endif
