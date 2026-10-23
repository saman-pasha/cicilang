// statics constructed at compile time are destroyed at exit (0.192), in the reverse order of their construction, the
// dynamically initialized ones among them: at namespace scope, a static data member, an inline one, local statics
#include <cstdio>
struct Cnt { int n; Cnt(int k) : n(k) {} ~Cnt() { std::printf("~Cnt %d\n", n); } };
struct K { int n; constexpr K(int k) : n(k) {} ~K() { std::printf("~K %d\n", n); } };
struct Loud { int n; Loud(int k) : n(k) { std::printf("Loud %d\n", n); } ~Loud() { std::printf("~Loud %d\n", n); } };
Cnt ca(1);
K ka(2);
Loud la(3);
struct H { static K hk; static inline Cnt hc{4}; };
K H::hk(5);
inline K ik(6);
static K sk(7);
int f() { static Cnt c(10); return c.n; }
int g() { static K k(20); return k.n; }
int h() { static Loud l(30); return l.n; }
int main() {
  std::printf("%d %d %d %d %d %d %d\n", ca.n, ka.n, la.n, H::hk.n, H::hc.n, ik.n, sk.n);
  std::printf("%d %d %d %d\n", f(), g(), h(), g());
  return 0;
}
