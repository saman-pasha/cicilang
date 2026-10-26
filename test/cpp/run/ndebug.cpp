// <cassert> DEFINES assert BY NDEBUG AS IT STANDS AT EACH INCLUSION ([cassert.syn], C17 7.2/1; 0.214): defined, assert
// is ((void)0) and its operand is not evaluated; undefined and the header included again, assert checks again. NDEBUG
// went unseen, and the first assert(false) aborted
#define NDEBUG
#include <cassert>
#include <cstdio>
#include <string>
static int calls;
static bool touch() { return ++calls > 0; }
static void off() { assert(false); assert(touch()); std::puts("off"); }
#undef NDEBUG
#include <cassert>
static void on(const std::string &s) { assert(s == "on"); assert(touch()); std::puts(s.c_str()); }
int main() {
  off();
  on("on");
  std::printf("%d\n", calls);
  return 0;
}
