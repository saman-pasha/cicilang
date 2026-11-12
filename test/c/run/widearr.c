/* AN ARRAY OF WIDE CHARACTERS AT FILE SCOPE, OR STATIC, MADE OF A WIDE LITERAL (0.298; C17 6.7.9/14-15): wchar_t,
   char16_t and char32_t, a bound that the literal gives and one that it does not fill, two literals joined, a static
   local's, beside a pointer to one and a block's arrays. Each was refused, global_init; the line is clang's */
#include <stdio.h>
#include <wchar.h>
#include <uchar.h>
static const wchar_t gw[] = L"abc";
static const char16_t g16[] = u"de";
static const char32_t g32[] = U"fgh";
static wchar_t gw5[5] = L"xy";
const wchar_t *gp = L"ptr";
static const wchar_t gj[] = L"jo" L"in";
int main(void) {
  wchar_t lw[] = L"local";
  char16_t l16[] = u"l16";
  static const char32_t s32[] = U"st";
  printf("%zu %zu %zu %zu %u %u %u %zu %u %zu %zu %zu %u\n", sizeof gw, sizeof g16, sizeof g32, sizeof gw5, (unsigned)gw[2], (unsigned)g16[1], (unsigned)g32[2], wcslen(gp), (unsigned)gw5[3], sizeof lw, sizeof l16, sizeof gj / sizeof gj[0], (unsigned)s32[1]);
  return 0;
}
