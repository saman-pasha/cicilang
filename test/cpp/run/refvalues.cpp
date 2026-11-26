// values read through a local reference (1.6.23): the check holds a local reference as the pointer it is, and a value
// computed from it is the referent's -- `return cr + 1;' over `const int &cr = x;' was refused, `a borrow leaves the
// function', an int that no pointer is; a pointer out of the reference's referent is a borrow still (the driver gate)
#include <cstdio>
int sum(int base) {
  int x = base;
  const int &cr = x;
  int &r = x;
  r += 2;
  return cr + 1;
}
long twice(long v) {
  long y = v;
  const long &ry = y;
  return ry * 2 - (ry > 3 ? 1 : 0);
}
double half(double d) {
  double z = d;
  double &rz = z;
  return rz / 2 + 0.25;
}
int pick(int a, int b) {
  int m = a, n = b;
  const int &lo = m < n ? m : n;
  return lo - 1;
}
int main() {
  std::printf("%d %ld %g %d\n", sum(4), twice(5), half(3.0), pick(9, 4));
  return 0;
}
