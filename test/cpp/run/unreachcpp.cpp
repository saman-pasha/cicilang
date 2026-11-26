// __builtin_unreachable() in the program's own C++ (1.6.23): LLVM's terminator at run time -- a switch's default, a
// conditional's arm, an if's branch -- and a constant evaluation's trap, so that a constexpr variable whose evaluation
// reaches it is refused (the driver gate); it was answered as nothing, and `f(-1)' folded to -1
#include <cstdio>
constexpr int f(int x) { if (x < 0) __builtin_unreachable(); return x * 2; }
constexpr int g = f(4);
int pick(int k) { switch (k) { case 1: return 10; case 2: return 20; default: __builtin_unreachable(); } }
int sel(int k) { return k > 0 ? k : (__builtin_unreachable(), 0); }
int main() { std::printf("%d %d %d %d\n", g, f(3), pick(2), sel(5)); return 0; }
