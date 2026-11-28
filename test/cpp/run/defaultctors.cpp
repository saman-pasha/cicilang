// THE DEFAULT CONSTRUCTORS AND DESTRUCTORS THAT 1.6.55'S RULES KEEP (cpp_default_fault/2, cpp_dtor_fault/2): each form here is one
// that clang++ takes beside the refusals of test/cpp/defctor_*.cpp, dtor_*.cpp and ctor_*.cpp
#include <cstdio>
#include <initializer_list>
struct B { int v; B(int x) : v(x) {} B() : v(7) {} };
struct D : B { using B::B; };                          // the base's default constructor builds the implicit one's base
struct K { const int k = 2; int j; };                    // a const member with a default member initializer
struct R { int &r; };                                    // a reference member, given by braces
struct X { X() = delete; X(int a) : v(a) {} int v; };
struct H { X x = X(3); H() {} };                         // a member whose default constructor is deleted, given by its initializer
struct I { X x{4}; };                                    // ... in an implicit one
template <class T> struct T1 { int t; T1(int a) : t(a) {} };
struct U : T1<int> { U() : T1(5) {} };                   // a base named by its template's name
struct V : T1<int> { V() : T1<int>(6) {} };
struct Dflt { int a = 8; Dflt() = default; };            // `= default' with nothing that deletes it
struct Pack { int n; template <class... A> Pack(A... as) : n(sizeof...(as)) {} };   // a constructor template that takes nothing
struct L { int n; L(std::initializer_list<int> il) : n((int)il.size()) {} };   // `L l{}' takes the list constructor, no default one
struct RC { int &r; const int c; RC(int &i) : r(i), c(9) {} };   // a constructor that gives both
struct Del { ~Del() = delete; int z; };                  // a destructor deleted, the class used through a pointer that no delete reaches
struct G { int g; G(int a) : g(a) {} };
struct NoUse { X x; int k = 1; };                       // its implicit default constructor deleted by x, made by its class and never called
G global(10);                                            // a global with an argument
static Del *keep;
int main() {
  D d; D e(3);
  K k{}; int i = 5; R r{i};
  H h; I in;
  U u; V v;
  Dflt df; Pack p; L l{};
  RC rc(i);
  X *x = new X(11);
  NoUse nu{X(12), 2};
  std::printf("%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n", d.v, e.v, k.k, r.r, h.x.v, in.x.v, u.t, v.t, df.a, p.n, l.n, rc.r, rc.c, global.g, x->v, nu.x.v, nu.k);
  delete x;
  (void)keep;
  return 0;
}
