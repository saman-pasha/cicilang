#include <ccomplex>
#include <cerrno>
#include <cfloat>
#include <ciso646>
#include <codecvt>
#if __has_include(<cstdalign>)
#include <cstdalign>
#endif
#include <cstdarg>
#include <cstdbool>
#include <climits>
#include <cstdio>
#include <cstdlib>
#include <ctgmath>
#include <cwctype>
#include <locale>
#include <ratio>
#include <string>
#include <strstream>
#include <version>
// the standard headers that no other fixture includes: the C library's <cerrno>, <cfloat>, <cstdarg> and <cwctype>;
// C++17's <ccomplex>, <ciso646>, <cstdalign>, <cstdbool> and <ctgmath>, deprecated; <codecvt> and <strstream>,
// deprecated; <ratio> and <version>
static int sum(int n, ...) {
  va_list ap;
  va_start(ap, n);
  int s = 0;
  for (int i = 0; i < n; ++i) s += va_arg(ap, int);
  va_end(ap);
  return s;
}
int main() {
  errno = 0;
  long big = std::strtol("99999999999999999999", nullptr, 10);
  std::printf("%d %d %d\n", (int) (big == LONG_MAX), (int) (errno == ERANGE), (int) (EDOM != ERANGE));
  std::printf("%d %d %d\n", FLT_DIG, DBL_MANT_DIG, (int) (LDBL_DIG >= 15));
  std::printf("%d %d %d\n", sum(3, 1, 2, 3), (int) (std::iswalpha(L'x') != 0), (int) std::towupper(L'q'));
  std::complex<double> z(3, 4);
  std::printf("%.1f %.1f\n", std::abs(z), std::sqrt(16.0));
  using R = std::ratio_add<std::ratio<1, 3>, std::ratio<1, 6>>;
  std::printf("%ld/%ld %d %ld\n", (long) R::num, (long) R::den, (int) std::ratio_less<std::ratio<1, 3>, std::ratio<1, 2>>::value,
              (long) std::ratio_multiply<std::kilo, std::milli>::num);
  std::wstring_convert<std::codecvt_utf8<wchar_t>> conv;
  std::wstring w = conv.from_bytes("caf\xc3\xa9");
  std::string back = conv.to_bytes(w);
  std::printf("%zu %zu %d\n", w.size(), back.size(), (int) (back == "caf\xc3\xa9"));
  std::strstream ss;
  ss << "n=" << 42 << std::ends;
  std::printf("%s\n", ss.str());
  ss.freeze(false);
  std::istrstream in("7 8");
  int a = 0, b = 0;
  in >> a >> b;
  bool t = true and not false;
  std::printf("%d %d %d %d\n", a + b, (int) t, (int) (__cpp_lib_optional >= 201606L), (int) alignof(std::max_align_t) >= 8);
  return 0;
}
