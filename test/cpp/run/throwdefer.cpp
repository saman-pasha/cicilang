// 0.237: the defer rule met -- an owner live where a call may throw is freed by a defer the unwinding runs; inside a try
// the handler takes it; a call that cannot throw (the C library's, a noexcept function) asks nothing
#include <cstdio>
#include <stdexcept>
static int risky(int k) {
  if (k > 2) throw std::runtime_error("big");
  return k;
}
static int quiet(int k) noexcept { return k + 1; }
int guarded(int k) {
  own int *p = new int(k);
  defer(p) { delete p; }
  return risky(*p) + quiet(*p);
}
int handled(int k) {
  own int *q = new int(k);
  int r = 0;
  try {
    r = risky(*q);
  } catch (const std::exception &e) {
    r = -1;
  }
  delete q;
  return r;
}
int main() {
  own int *c = new int(5);
  std::printf("%d\n", quiet(*c));
  delete c;
  std::printf("%d %d\n", guarded(2), handled(1));
  try {
    guarded(7);
  } catch (const std::runtime_error &e) {
    std::printf("caught %s\n", e.what());
  }
  std::printf("%d\n", handled(9));
  return 0;
}
