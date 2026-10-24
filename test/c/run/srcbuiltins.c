#include <assert.h>
#include <stdio.h>
#include <string.h>
/* clang's source-location builtins in C: `__builtin_FILE()', `__builtin_FILE_NAME()', `__builtin_LINE()',
   `__builtin_COLUMN()' and `__builtin_FUNCTION()' at their own place; `assert' over glibc's `__FILE__' */
static const char *base(const char *p) {
  const char *s = strrchr(p, '/');
  return s ? s + 1 : p;
}
static int where(void) { return (int) __builtin_LINE(); }
int main(void) {
  printf("%s %s\n", base(__builtin_FILE()), __builtin_FILE_NAME());
  printf("%u %u %s\n", __builtin_LINE(), __builtin_COLUMN(), __builtin_FUNCTION());
  unsigned line =
      __builtin_LINE();
  printf("%u %d\n", line, where());
  const char *f = __builtin_FUNCTION();
  printf("%s %zu\n", f, sizeof(__builtin_LINE()));
  assert(where() == 10);
  puts("assert held");
  return 0;
}
