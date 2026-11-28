// GCC's alias of the Itanium name of what the program defines (1.6.58): a global function, overloads, references and
// pointers, a class by value, nested namespaces, an ellipsis, a static member function, a namespace's object and a
// static data member, each target spelled as clang++ mangles it; an alias declared before its target; an extern "C" one
#include <cstdio>
long early(long) __attribute__((alias("_ZN2ns5laterEl")));
int g_target(int x) { return x * 3; }
int g_alias(int x) __attribute__((alias("_Z8g_targeti")));
extern "C" int c_target(int x) { return x + 1; }
extern "C" int c_alias(int x) __attribute__((alias("c_target")));
int f(int x) { return x + 1; }
double f(double x) { return x * 2; }
int fa(int) __attribute__((alias("_Z1fi")));
double fd(double) __attribute__((alias("_Z1fd")));
int h(const int &r, int *p) { return r + *p; }
int ha(const int &, int *) __attribute__((alias("_Z1hRKiPi")));
struct P { int a, b; };
int sum(P p) { return p.a + p.b; }
int suma(P) __attribute__((alias("_Z3sum1P")));
namespace A { namespace B { int deep(char c, long n) { return c + (int) n; } } }
int deepa(char, long) __attribute__((alias("_ZN1A1B4deepEcl")));
int va(int n, ...) { return n * 10; }
int vaa(int, ...) __attribute__((alias("_Z2vaiz")));
namespace ns { long later(long v) { return v * 7; } namespace in { double half = 0.5; } int v = 7; }
extern int nva __attribute__((alias("_ZN2ns1vE")));
extern double ha2 __attribute__((alias("_ZN2ns2in4halfE")));
struct S { static int sf(int x) { return x + 2; } static int k; };
int S::k = 11;
int sfa(int) __attribute__((alias("_ZN1S2sfEi")));
extern int ka __attribute__((alias("_ZN1S1kE")));
int main() {
  int k = 4; P p = {2, 3};
  std::printf("%ld %d %d %d %.1f %d %d %d %d\n", early(3), g_alias(4), c_alias(4), fa(1), fd(1.5), ha(5, &k), suma(p), deepa('a', 3), vaa(2, 9));
  std::printf("%d %.1f %d %d\n", nva, ha2, sfa(3), ka);
  return 0;
}
