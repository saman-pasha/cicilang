// The exceptions mask of a stream: set and read back; with no exceptions in libc++'s configuration a failure only sets
// the state (the mask is kept, and nothing is thrown that the program could catch).
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
