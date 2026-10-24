#include <cassert>
#include <cstdio>
#include <cstring>
#include <type_traits>
// clang's source-location builtins: `__builtin_FILE()', `__builtin_FILE_NAME()', `__builtin_LINE()', `__builtin_COLUMN()'
// and `__builtin_FUNCTION()' at their own place, and in a default argument the place of the call; glibc's `assert' in
// C++ is written on the first two
static const char *base(const char *p) {
  const char *s = std::strrchr(p, '/');
  return s ? s + 1 : p;
}
static void log(const char *what, int line = __builtin_LINE(), const char *fn = __builtin_FUNCTION(),
                unsigned col = __builtin_COLUMN()) {
  std::printf("%s at %d in %s col %u\n", what, line, fn, col);
}
struct At {
  int line;
  At(int l = __builtin_LINE()) : line(l) {}
};
struct K {
  void m() { log("member"); }
};
int twice(int x) {
  log("twice");
  return 2 * x;
}
int main() {
  std::printf("%s %s\n", base(__builtin_FILE()), __builtin_FILE_NAME());
  std::printf("%d %u %s\n", __builtin_LINE(), __builtin_COLUMN(), __builtin_FUNCTION());
  log("main");
  log("again", 5);
  twice(3);
  K{}.m();
  At a;
  At b(9);
  std::printf("%d %d\n", a.line, b.line);
  std::printf("%d %d %d\n", (int) std::is_same_v<decltype(__builtin_LINE()), unsigned>,
              (int) std::is_same_v<decltype(__builtin_FILE()), const char *>,
              (int) std::is_same_v<decltype(__builtin_COLUMN()), unsigned>);
  int line =
      __builtin_LINE();
  std::printf("%d\n", line);
  assert(twice(2) == 4);
  int k = 1;
  assert(k > 0 && "positive");
  std::puts("asserts held");
  return 0;
}
