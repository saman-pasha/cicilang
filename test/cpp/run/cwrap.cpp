#include <cassert>
#include <cfenv>
#include <cinttypes>
#include <clocale>
#include <csetjmp>
#include <csignal>
#include <cstdio>
#include <cstring>
#include <cuchar>
#include <cwchar>
// the C library through the C++ headers that no fixture reached: <csetjmp>, <csignal>, <cfenv>, <clocale>,
// <cinttypes>, <cuchar>, <cassert>
static std::jmp_buf env;
static volatile std::sig_atomic_t got = 0;
extern "C" void handler(int s) { got = s; }
static void jump(int k) { std::longjmp(env, k); }
int main() {
  assert(1 + 1 == 2);
  volatile int count = 0;
  int r = setjmp(env);
  count = count + 1;
  if (r == 0) jump(5);
  std::printf("%d %d\n", r, (int) count);
  std::signal(SIGUSR1, handler);
  std::raise(SIGUSR1);
  std::printf("%d\n", got == SIGUSR1);
  std::printf("%d\n", std::fegetround() == FE_TONEAREST);
  volatile double a = 1.0, b = 3.0;
  std::fesetround(FE_UPWARD);
  double up = a / b;
  std::fesetround(FE_DOWNWARD);
  double down = a / b;
  std::fesetround(FE_TONEAREST);
  std::printf("%d\n", up > down);
  std::feclearexcept(FE_ALL_EXCEPT);
  volatile double z = 0.0;
  volatile double inf = 1.0 / z;
  std::printf("%d %d\n", std::fetestexcept(FE_DIVBYZERO) != 0, inf > 1e308);
  std::int64_t big = INT64_C(1234567890123);
  std::printf("%" PRId64 " %" PRIx32 "\n", big, (std::uint32_t) 255);
  std::intmax_t m = std::strtoimax("-42", nullptr, 10);
  std::imaxdiv_t d = std::imaxdiv(17, 5);
  std::printf("%jd %jd %jd %jd\n", m, d.quot, d.rem, std::imaxabs(-9));
  std::printf("%s\n", std::setlocale(LC_ALL, "C"));
  std::printf("[%s]\n", std::localeconv()->decimal_point);
  char16_t c16;
  std::mbstate_t st{};
  std::size_t n = std::mbrtoc16(&c16, "A", 1, &st);
  std::printf("%zu %d\n", n, (int) c16);
  char out[8];
  std::mbstate_t st2{};
  std::size_t k = std::c32rtomb(out, U'Z', &st2);
  std::printf("%zu %c\n", k, out[0]);
  std::printf("%zu\n", std::wcslen(L"wide"));
  return 0;
}
