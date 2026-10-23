/* the predefined macros clang has on x86-64 Linux (0.194): C's __STDC_VERSION__, the function-like __INT64_C(c) and kin, the 64-bit types
   `long', wint_t unsigned, an empty __USER_LABEL_PREFIX__, the default CPU k8 (no SSE3), math errno on */
#include <stdio.h>
#include <stdint.h>
#include <wchar.h>
#define S_(x) #x
#define S(x) S_(x)
int main(void) {
  printf("stdc %ld\n", (long) __STDC_VERSION__);
  printf("c64 %d %d\n", (int) sizeof(__INT64_C(5)), (int) sizeof(__UINT64_C(5)));
  printf("int64 %s\n", _Generic((__INT64_TYPE__) 0, long: "long", long long: "long long", default: "?"));
  printf("intmax %s\n", _Generic((__INTMAX_TYPE__) 0, long: "long", long long: "long long", default: "?"));
  printf("wint %d %s\n", (int) sizeof(wint_t), (wint_t) -1 > 0 ? "unsigned" : "signed");
  printf("label [%s]\n", S(__USER_LABEL_PREFIX__));
#ifdef __k8__
  puts("k8");
#endif
#ifdef __SSE3__
  puts("sse3");
#endif
#ifdef __NO_MATH_ERRNO__
  puts("no math errno");
#endif
#ifdef _GNU_SOURCE
  puts("gnu source");
#endif
  printf("%s %s\n", S(__INT64_C(7)), S(__UINT64_C(7)));
  return 0;
}
