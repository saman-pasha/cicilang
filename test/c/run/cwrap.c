#include <assert.h>
#include <fenv.h>
#include <inttypes.h>
#include <locale.h>
#include <setjmp.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <uchar.h>
#include <wchar.h>
/* the C library's headers that no fixture reached: setjmp and longjmp (a local changed between them is volatile),
   signal and raise, the floating environment, the locale, <inttypes.h>'s formats and conversions, <uchar.h> */
static jmp_buf env;
static volatile sig_atomic_t got = 0;
static void handler(int s) { got = s; }
static void jump(int k) { longjmp(env, k); }
static int depth(int n) { if (n == 0) jump(7); return depth(n - 1) + 1; }
int main(void) {
  assert(1 + 1 == 2);
  volatile int count = 0;
  int r = setjmp(env);
  count++;
  if (r == 0) jump(5);
  printf("%d %d\n", r, count);
  if (setjmp(env) == 0) depth(10);
  else printf("deep\n");
  signal(SIGUSR1, handler);
  raise(SIGUSR1);
  printf("%d\n", got == SIGUSR1);
  printf("%d\n", fegetround() == FE_TONEAREST);
  volatile double a = 1.0, b = 3.0;
  fesetround(FE_UPWARD);
  double up = a / b;
  fesetround(FE_DOWNWARD);
  double down = a / b;
  fesetround(FE_TONEAREST);
  printf("%d\n", up > down);
  feclearexcept(FE_ALL_EXCEPT);
  volatile double z = 0.0;
  volatile double inf = 1.0 / z;
  printf("%d %d\n", fetestexcept(FE_DIVBYZERO) != 0, inf > 1e308);
  int64_t big = INT64_C(1234567890123);
  printf("%" PRId64 " %" PRIx32 " %" PRIu8 "\n", big, (uint32_t) 255, (uint8_t) 200);
  intmax_t m = strtoimax("-42", NULL, 10);
  uintmax_t u = strtoumax("ff", NULL, 16);
  imaxdiv_t d = imaxdiv(17, 5);
  printf("%jd %ju %jd %jd %jd\n", m, u, d.quot, d.rem, imaxabs(-9));
  printf("%s\n", setlocale(LC_ALL, "C"));
  struct lconv *lc = localeconv();
  printf("[%s]\n", lc->decimal_point);
  char16_t c16;
  mbstate_t st;
  memset(&st, 0, sizeof st);
  size_t n = mbrtoc16(&c16, "A", 1, &st);
  printf("%zu %d\n", n, (int) c16);
  char out[8];
  mbstate_t st2;
  memset(&st2, 0, sizeof st2);
  size_t k = c32rtomb(out, U'Z', &st2);
  printf("%zu %c\n", k, out[0]);
  printf("%zu %d\n", wcslen(L"wide"), wcscmp(L"a", L"b") < 0);
  return 0;
}
