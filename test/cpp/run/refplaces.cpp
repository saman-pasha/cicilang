// places through references and values (1.6.22): a store through a reference to a pointer, the address of what a
// returned reference names, GNU's ?: of two lvalues as a place, and a functional cast to a decltype type. Until 1.6.22
// `*q = 9' over `int *&q = p;' was refused `no owner behind', `int *p = &hr();' `plain pointer not consumed', `x ?: y' a
// syntax error and `decltype(mm)(5)' `not lowered yet: expr(decltype_expr(...))'
#include <cstdio>
static int hv = 3;
int &hr() { return hv; }
struct M { int v; M(int x) : v(x) {} };
int main() {
  int *p0 = &hr();
  *p0 = 4;
  int arr[3] = {0, 0, 0};
  int *p = arr;
  int *&q = p;
  *q = 9;
  q += 1;
  *q = 8;
  q[1] = 7;
  int x = 0, y = 6;
  int &e = (x ?: y);
  e = 5;
  int z = (y ?: 1) + (0 ?: 2);
  M mm(1);
  auto r = decltype(mm)(5);
  decltype(x) c = decltype(x)(2.9);
  std::printf("%d %d %d %d %d %d %d %d %d\n", hv, arr[0], arr[1], arr[2], *p, y, z, r.v, c);
  return 0;
}
