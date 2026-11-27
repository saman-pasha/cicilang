// GCC's weak, section and an extern "C" alias in C++ (1.6.40), as clang++ has them
#include <cstdio>
__attribute__((weak)) int wf() { return 1; }
__attribute__((weak)) void missing();
__attribute__((section("mysec"))) int in_sec = 5;
__attribute__((section(".text.hot"))) int hot() { return 3; }
__attribute__((weak)) int wv = 7;
extern "C" int c_target(int x) { return x * 2; }
extern "C" int c_alias(int x) __attribute__((alias("c_target")));
int main() { std::printf("%d %d %d %d %d %d\n", wf(), missing ? 1 : 0, in_sec, hot(), wv, c_alias(4)); return 0; }
