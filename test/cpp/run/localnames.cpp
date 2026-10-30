// 0.236: a local class's type information is its local name, `Z <the function's encoding> E <name> [_n]', as clang++
// spells it: a constructor `C1', a destructor `D1', an operator's code, a conversion `cv', a static function `L', an
// `extern "C"' one its name alone, an inline namespace and an unnamed one in the path, a template's instance its
// arguments and its pattern's words (`T_', a pack `DpT_', `DTplfp_Li1EE', `Dtfp_E', `1AIXplT_Li1EEE'); an unnamed class
// of a class `Ut_', `Ut0_', one of a function `$_N' or, inline, `Ut_'
#include <cstdio>
#include <typeinfo>
#define P(x) std::printf("%s\n", typeid(x).name())
struct K {
  K() { struct L {}; P(L); }
  ~K() { struct L {}; P(L); }
  int operator+(int) { struct L {}; P(L); return 0; }
  operator int() { struct L {}; P(L); return 0; }
  static void s(char) { struct L {}; P(L); }
  struct N { void m() const { struct L {}; P(L); } };
};
struct U { struct { int x; } m; enum { A1, B1 } e; };
template <class T> struct TC { void m() { struct L {}; P(L); } };
template <class T> T tf(T t) { struct L {}; P(L); return t; }
template <class... T> void pk(T...) { struct L {}; P(L); }
template <class T> auto dt(T t) -> decltype(t + 1) { struct L {}; P(L); return t; }
template <class T> auto dn(T t) -> decltype(t) { struct L {}; P(L); return t; }
template <int N> struct A {};
template <class T> struct A2 {};
template <class T> void dv(A2<T>) { struct L {}; P(L); }
template <int N> void xe(A<N + 1>) { struct L {}; P(L); }
extern "C" void cf() { struct L {}; P(L); }
namespace ns { inline namespace in { void nf() { struct L {}; P(L); } } }
namespace { void af() { struct L {}; P(L); } }
static void sf() { struct L {}; P(L); }
void g1(int, double) {
  struct L {}; P(L);
  { struct L {}; P(L); }
}
inline void il() { struct { int z; } v; P(v); }
void nl() { struct { int z; } v; struct { int y; } w; P(v); P(w); }
int main() {
  { K k; int x = k + 1; x = k; K::s('a'); K::N{}.m(); }
  P(U{}.m); P(U{}.e);
  TC<int>{}.m(); TC<double>{}.m(); tf(1); tf(2.0); pk(1, 2.0); dt(1); dn(1); xe<2>(A<3>{}); dv(A2<char>{});
  cf(); ns::nf(); af(); sf(); g1(1, 2); il(); nl();
  struct M { int q; }; P(M); P(M *); P(const M &);
  return 0;
}
