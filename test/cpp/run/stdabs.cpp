// std::abs OF AN INT WITH <chrono> AND <cmath> (0.160): glibc's abs, as clang++ chooses it over libc++ 21's template
// std::__math::abs(int); a header read cold in the process noted only the first namespace path of `abs', and the build
// called glibc's function by a C++ symbol no library has. The gate builds warm, so it holds the warm road
#include <chrono>
#include <cmath>
#include <cstdio>
int main() {
  std::printf("%d %.1f\n", (int) std::abs(-4), std::floor(2.7));
  return 0;
}
