#include <cstdio>
// a destructor that throws at its scope's end: the objects not destroyed yet are, once each, as the exception unwinds,
// and a try the exit has left catches nothing
struct D { int n; ~D() noexcept(false) { std::printf("~D%d\n", n); if (n == 2) throw n; } };
int f() {
  D a{1};
  try {
    D b{2};
    D c{3};
    return 0;
  } catch (int e) { std::printf("caught in f %d\n", e); }
  return 1;
}
int g() {
  D outer{2};
  try { return 5; } catch (int) { std::printf("wrong\n"); }
  return 6;
}
int main() {
  std::printf("f %d\n", f());
  try { g(); } catch (int e) { std::printf("caught in main %d\n", e); }
  try { D x{4}; D y{2}; D z{5}; } catch (int e) { std::printf("caught %d\n", e); }
  for (int i = 0; i < 2; i++) {
    try { D w{7}; D v{2}; if (i == 1) break; } catch (int e) { std::printf("loop caught %d\n", e); }
  }
  return 0;
}
