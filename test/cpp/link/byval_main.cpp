// built by cicilang++ in the C++ gate, linked with clang++'s byval_helper.o (byval.h)
#include "byval.h"
int here(T t) { return t.v * 2; }
int main() {
  std::printf("[%d] ", there(T(1)));
  {
    T a(2);
    std::printf("[%d] ", there(a));
  }
  std::printf("[%d] ", call_here(3));
  std::printf("live %d\n", byval_live);
  return 0;
}
