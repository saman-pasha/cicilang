/* A LONG DOUBLE LITERAL KEEPS ITS EXACT VALUE (0.154): its text is rounded once to the long double's own format, as clang
   reads it -- an x87's 64 bits here, a quad's 113 on aarch64 Linux -- in a function, in a global's fold, through its casts
   and its arithmetic; `%La' prints each value exactly. It held the double nearest its text: LDBL_MAX and 1e999L were the
   largest double, LDBL_MIN a zero, 0.1L a double's 0.1; and `(double) 1 / 3' at file scope folded to 0. A sum of far operands rounds as the exact sum does without
   aligning 32,000 bits, and an integer operand is converted to the long double before the operation (C 6.3.1.8) */
#include <stdio.h>
#include <float.h>

long double g_max = LDBL_MAX, g_min = LDBL_MIN, g_true = LDBL_TRUE_MIN, g_eps = LDBL_EPSILON;
long double g_tenth = 0.1L, g_pi = 3.14159265358979323846264338327950288419716939937510L;
long double g_third = 1.0L / 3.0L, g_sum = 0.1L + 0.2L, g_prod = 0.1L * 3, g_neg = -LDBL_MAX, g_over = LDBL_MAX * 2;
long double g_int = 9007199254740993, g_cast = (long double) 9007199254740993, g_div = (long double) 1 / 3;
long double g_hex = 0x1.8p1L, g_hex2 = 0xA.Bp-1L, g_hex3 = 0x.8p-2L, g_hex4 = 0x1.p3L, g_hex5 = 0XAbCp-3L, g_tiny = 0x1p-16445L;
long double g_big = 1e999L, g_inf = 1e99999L, g_zero = 1e-99999L, g_nz = -0.0L, g_pz = 1.0L - 1.0L, g_sub = LDBL_MIN / 4, g_nan = 0.0L / 0.0L;
long double g_tie = 1.00000000000000000005421010862427522170037264004349708557128906250L;   /* 1 + 2^-64: the x87's tie, to even */
long double g_above = 1.00000000000000000005421010862427522170037264004349708557128906251L;
double d_tenth = 0.1L, d_third = (double) 1 / 3, d_sub = 1e-320L, d_ld = (double) LDBL_MIN;
float f_tenth = 0.1L, f_tiny = 1e-50L;
int i_trunc = 2.9L, i_neg = -2.9L;
#if LDBL_MANT_DIG >= 64
unsigned long long u_max = 18446744073709551615.0L;   /* exact in an x87's 64 bits and a quad's 113 */
#else
unsigned long long u_max = 18446744073709549568.0L;   /* where a long double is a double (Apple's arm64), 2^64 - 1 rounds to 2^64,
                                                         out of range (C 6.3.1.4): 2^64 - 2048, the largest double below it (0.248) */
#endif
long long ll_big = -9007199254740993.0L;
_Bool b_half = 0.5L;
_Complex long double z = 1.5L + 2.5Li, z2 = 0.1Li;
long double s_far = 1.0L + 1e-4900L, s_far2 = 1.0L - 1e-4900L, s_maxtiny = LDBL_MAX + LDBL_TRUE_MIN, s_nmax = -LDBL_MAX - LDBL_TRUE_MIN;
long double s_tinybig = LDBL_TRUE_MIN - 1e4000L, s_minus = LDBL_MIN - LDBL_TRUE_MIN, s_maxone = LDBL_MAX + 1, s_eps = 1.0L + (LDBL_EPSILON / 2 + LDBL_TRUE_MIN);
long double s_i1 = (((__int128) 1 << 64) + 1) + 0.5L, s_i2 = (((__int128) 1 << 64) + 1) * 3.0L, s_i3 = (((__int128) 1 << 120) + 128) * 3.0L;
long double s_i4 = (((__int128) 1 << 100) + 1) + 1e-4000L, s_i5 = 1.0L / (((__int128) 1 << 64) + 1);
double d_far = 1.0L + 1e-4900L, d_maxtiny = LDBL_MAX + LDBL_TRUE_MIN;

static void p(const char *n, long double x) { printf("%-7s %La\n", n, x); }

int main(void) {
    p("max", g_max); p("min", g_min); p("true", g_true); p("eps", g_eps); p("tenth", g_tenth); p("pi", g_pi);
    p("third", g_third); p("sum", g_sum); p("prod", g_prod); p("neg", g_neg); p("over", g_over);
    p("int", g_int); p("cast", g_cast); p("div", g_div);
    p("hex", g_hex); p("hex2", g_hex2); p("hex3", g_hex3); p("hex4", g_hex4); p("hex5", g_hex5); p("tiny", g_tiny);
    p("big", g_big); p("inf", g_inf); p("zero", g_zero); p("nz", g_nz); p("pz", g_pz); p("sub", g_sub); p("nan", g_nan);
    p("tie", g_tie); p("above", g_above);
    printf("double  %a %a %a %a\n", d_tenth, d_third, d_sub, d_ld);
    printf("float   %a %a\n", (double) f_tenth, (double) f_tiny);
    printf("integer %d %d %llu %lld %d\n", i_trunc, i_neg, u_max, ll_big, (int) b_half);
    printf("complex %La %La %La %La\n", __real__ z, __imag__ z, __real__ z2, __imag__ z2);
    p("far", s_far); p("far2", s_far2); p("maxtiny", s_maxtiny); p("nmax", s_nmax); p("tinybig", s_tinybig); p("minus", s_minus);
    p("maxone", s_maxone); p("eps2", s_eps); p("i1", s_i1); p("i2", s_i2); p("i3", s_i3); p("i4", s_i4); p("i5", s_i5);
    printf("dfar    %a %a\n", d_far, d_maxtiny);
    /* in a function: the literals are the code's constants */
    long double a = LDBL_MAX, b = 0.1L, c = 0x1.fffffffffffffffep16383L, d = 1e99999L, e = 3.6451995318824746025e-4951L, f = .5e-3L;
    p("fmax", a); p("ftenth", b); p("fhex", c); p("finf", d); p("fsub", e); p("fdot", f);
    printf("fcmp    %d %d %d\n", a > 1e308L, e > 0.0L, b != 0.1);
    /* the machine's own arithmetic over them */
    volatile long double v = 0.1L;
    p("v*3", v * 3); p("v/3", v / 3.0L);
    return 0;
}
