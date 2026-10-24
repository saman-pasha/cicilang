#include <cstdio>
// a constructor that throws destroys what it built ([except.ctor]/3), and a function-try-block's handler sees them destroyed
struct M { int k; M(int k) : k(k) { std::printf("M%d\n", k); } ~M() { std::printf("~M%d\n", k); } };
int boom(int k) { if (k == 2) throw k; return k; }
struct B { M m{9}; B() { std::printf("B\n"); } ~B() { std::printf("~B\n"); } };
struct T : B { M a; M b; M c; T() : a(1), b(boom(2)), c(3) { std::printf("T body\n"); } ~T() { std::printf("~T\n"); } };
struct U { M a; M b; U() : a(4), b(5) { std::printf("U body\n"); throw 7; } ~U() { std::printf("~U\n"); } };
struct V { M a; V() try : a(6) { std::printf("V body\n"); throw 8; } catch (int e) { std::printf("V handler %d\n", e); } };
int f(int x) try { if (x) throw x; return 1; } catch (int e) { std::printf("f handler %d\n", e); return 2; }
struct W { M a; M b; W() try : a(10), b(boom(2)) {} catch (...) { std::printf("W handler\n"); throw 11; } };
int main() {
  try { T t; } catch (int e) { std::printf("caught %d\n", e); }
  try { U u; } catch (int e) { std::printf("caught %d\n", e); }
  try { V v; } catch (int e) { std::printf("caught %d\n", e); }
  std::printf("%d %d\n", f(0), f(3));
  try { W w; } catch (int e) { std::printf("caught %d\n", e); }
  return 0;
}
