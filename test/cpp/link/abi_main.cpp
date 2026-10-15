// built by cicilang++ in the C++ gate, linked with clang++'s abi_helper.o (abi.h)
#include <cstdio>
#include "abi.h"
int main() {
  D d = make_d(1, 2, 3);
  VD vd; vd.b = 4; vd.y = 5;
  std::printf("%d %d %d %d | %d | %d %d | %d %d\n", d.a, d.c, d.d, sum_d(D(10, 20, 30)), sum_vd(vd), size_d(), (int) sizeof(D), size_vd(), (int) sizeof(VD));
  return 0;
}
