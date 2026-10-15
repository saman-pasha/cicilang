// built by clang++ in the C++ gate (abi.h)
#include "abi.h"
D make_d(int a, char c, char d) { return D(a, c, d); }
int sum_d(D v) { return v.a + v.c + v.d; }
int sum_vd(const VD &v) { return v.b * 10 + v.y + v.f() * 100; }
int size_d(void) { return (int) sizeof(D); }
int size_vd(void) { return (int) sizeof(VD); }
