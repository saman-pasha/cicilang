// The exceptions mask of a stream: set and read back; a failed read sets failbit, which a mask of badbit does not hold,
// so nothing is thrown (iosfailure.cpp throws through a mask of failbit, 0.193).
#include <cstdio>
#include <sstream>
int main() {
  std::istringstream in("12 x");
  std::printf("%d ", (int) in.exceptions());
  in.exceptions(std::ios::badbit);
  std::printf("%d ", (int) (in.exceptions() == std::ios::badbit));
  int a = 0, b = 0;
  in >> a >> b;
  std::printf("%d %d %d\n", a, (int) in.fail(), (int) in.bad());
  return 0;
}
