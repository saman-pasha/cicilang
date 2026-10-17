// built by cicilang++ in the C++ gate and the cross gate, linked with clang++'s memptr_helper.o (memptr.h)
#include <cstdio>
#include "memptr.h"
int main() {
  C c;
  CM ms[] = { &C::va, &C::na, &C::vb, &C::nb, &C::nc };
  for (CM m : ms) std::printf("%d ", call_cm(&c, m));
  std::printf("|");
  for (int k = 0; k < 5; k++) { CM m = get_cm(k); std::printf(" %d", (c.*m)()); }
  CM none = nullptr, got = get_cm(9);
  std::printf(" | %d %d %d %d\n", is_null(none), is_null(&C::va), is_null(&C::na), got ? 0 : 1);
  return 0;
}
