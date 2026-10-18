// __func__, __FUNCTION__ and __PRETTY_FUNCTION__ as clang spells them: the function's own name, and its signature --
// its result and parameters as written, a template's pattern's with its arguments in brackets, a lambda's context
#include <cstdio>
#include <cstddef>
#include <string>
#include <vector>
#include <utility>
#define P() std::printf("%s | %s | %s\n", __func__, __FUNCTION__, __PRETTY_FUNCTION__)

int free1() { P(); return 1; }
int over(int) { P(); return 2; }
int over(double, const char *) { P(); return 3; }
void refs(int &, const int &, int &&, int *, const char *const, unsigned long, long long, signed char, bool) { P(); }
void vari(int, ...) { P(); }
void str(std::string, const std::string &) { P(); }
namespace ns { namespace in { void deep() { P(); } } }
struct K {
  K() { P(); }
  K(int) { P(); }
  ~K() { P(); }
  void m() { P(); }
  int c() const { P(); return 0; }
  static long s(char) { P(); return 0; }
  virtual void v() { P(); }
  K &operator+=(const K &) { P(); return *this; }
  operator int() const { P(); return 0; }
  template <class T> T tm(T x) { P(); return x; }
  struct In { void im() { P(); } };
  void rq() & { P(); }
  void rr() && { P(); }
};
struct D : K { void v() override { P(); } };
template <class T> T tf(T x) { P(); return x; }
template <class T, int N> struct S { void f() { P(); } static int g(T) { P(); return N; } };
int operator-(const K &, int) { P(); return 0; }
template <unsigned N> void un() { P(); }
template <long N> void lo() { P(); }
template <char C> void ch() { P(); }
template <bool B> void bo() { P(); }
template <class... Ts> void pk(Ts...) { P(); }
template <class T, unsigned N = 3> struct U { void f() { P(); } };
template <class T> struct O { template <class V> struct I { void g() { P(); } }; };
template <class T> void tv(const std::vector<T> &) { P(); }
template <class T> T *tp(T *p) { P(); return p; }
template <class T> void tl(T) { [] { P(); }(); }
int f(int x) { auto l = [] { P(); }; l(); return x; }
struct M { void m(int) { auto l = [](double) { P(); auto in = [] { P(); }; in(); }; l(1.0); } };
struct L { void loc() { struct Loc { void lf() { P(); } }; Loc().lf(); } };
using u32 = unsigned int; typedef long lg;
void tdef(u32, lg, size_t, std::size_t) { P(); }
auto au() { P(); return 1; }
auto tr() -> int { P(); return 1; }
decltype(auto) da() { P(); return 1; }
namespace n { struct C { void m(); static void s(); bool operator==(const C &) const { P(); return true; } int operator[](int) { P(); return 0; } void operator()(int, char) { P(); } }; }
void n::C::m() { P(); }
void n::C::s() { P(); }
template <class T> struct Sp { void f() { P(); } };
template <class T> struct Sp<T *> { void f() { P(); } };
template <> struct Sp<int> { void f() { P(); } };
template <class T> void fp(T) { P(); }
int g1(int x, int y = 2, ...) { P(); return x + y; }
template <class T> void vv(T &&) { P(); }
template <class T> struct Cn { Cn(T) { P(); } ~Cn() { P(); } };
template <char C, bool B, unsigned long N, short Sh, int I> struct X { void f() { P(); } };
void arr(int a[], int b[5], char *argv[], int (*fn)(int), int (&r)[3]) { P(); }

int main() {
  P();
  free1(); over(1); over(1.0, "x");
  int a = 0; refs(a, a, 1, &a, "", 0, 0, 0, true);
  vari(1, 2);
  str("a", "b");
  ns::in::deep();
  { K k; K k2(1); k.m(); k.c(); K::s('a'); k.v(); k += k2; (void) (int) k; k.tm(2.5); K::In().im(); k.rq(); K().rr(); (void) (k - 1); }
  { D d; K &b = d; b.v(); }
  tf(3); tf<char>('c');
  S<int, 4>().f(); S<double, 2>::g(1.0);
  un<4>(); lo<-3>(); ch<'c'>(); bo<true>(); pk(1, 2.0, (const char *) "x"); pk();
  U<int>().f(); U<char, 7>().f(); O<int>::I<double>().g();
  tv(std::vector<int>{}); tv(std::vector<std::vector<int>>{});
  int i = 0; tp(&i); const char *cs = ""; tp(cs);
  tl(1); tl(2.5);
  f(1); M().m(1); L().loc();
  tdef(0, 0, 0, 0); au(); tr(); da();
  n::C c; c.m(); n::C::s(); (void) (c == c); c[1]; c(1, 'a');
  Sp<int *>().f(); Sp<int>().f(); Sp<double>().f();
  fp(&g1); fp(std::make_pair(1, 'c')); int z = 0; vv(z); vv(3);
  { Cn<double> cn(1.0); }
  g1(1);
  X<'c', true, 5, 2, -1>().f();
  arr(nullptr, nullptr, nullptr, nullptr, *(int (*)[3]) &i);
  [] { P(); }();
  auto ml = [](int x) mutable { P(); return x; }; ml(1);
  auto gl = [](auto x, int) { P(); return x; }; gl(1, 2); gl(2.5, 3);
  return 0;
}
