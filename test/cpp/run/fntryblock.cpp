#include <cstdio>
#include <string>
// what a throwing constructor has built is destroyed: a base with nothing to construct, a later base, the implicit
// copy constructor's members; function-try-blocks of a method, a destructor and a free function
struct M { int k; M(int k) : k(k) { std::printf("M%d\n", k); } M(const M &o) : k(o.k + 10) { if (k == 13) throw k; std::printf("copy M%d\n", k); } ~M() { std::printf("~M%d\n", k); } };
struct E { ~E() { std::printf("~E\n"); } };
struct P { M p{7}; };
struct T : E, P { M a{1}; M b{2}; T() { std::printf("T body\n"); throw 5; } };
struct C { M x{1}; M y{2}; M z{3}; };
struct K { std::string s{"kept"}; int f(int v) try { if (v < 0) throw v; return v * 2; } catch (int e) { std::printf("f %s %d\n", s.c_str(), e); return 0; } };
struct D { int n; ~D() noexcept(false) try { std::printf("~D body\n"); if (n) throw n; } catch (int e) { std::printf("~D handler %d\n", e); } };
int g(int v) try { if (v) throw v + 1; return 0; } catch (int e) { return e; }
int main() {
  try { T t; } catch (int e) { std::printf("caught %d\n", e); }
  C c1;
  try { C c2 = c1; } catch (int e) { std::printf("caught %d\n", e); }
  K k;
  std::printf("%d %d\n", k.f(3), k.f(-4));
  try { D d{6}; } catch (int e) { std::printf("caught %d\n", e); }
  std::printf("%d %d\n", g(0), g(8));
  return 0;
}
