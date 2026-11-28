// Static data members that are pointers to functions (1.6.57): declared in the class with `static' in their result's
// words, defined out of the class with the qualified name in the parenthesized declarator, called by the class's name, through
// an object and through a pointer, in arrays, as references, in a template and its specialization; and a base's static
// member function named through the derived class, unless the derived class hides it; and static pointers to members
#include <cstdio>
static int f(int x) { return x + 1; }
static int g(int x) { return x * 3; }
static double mean(int n, ...) { return n / 2.0; }
struct M { static int (*pick)(int); static int (*tab[2])(int); static double (*avg)(int, ...); int v; };
int (*M::pick)(int) = f;
int (*M::tab[2])(int) = { f, g };
double (*M::avg)(int, ...) = mean;
namespace N { struct T { static int (*getp(int k))(int); static int (&ref)(int); }; }
int (*N::T::getp(int k))(int) { return k ? g : f; }
int (&N::T::ref)(int) = g;
template <class U> struct Q { static U (*conv)(U); static U k; };
static long twice(long x) { return 2 * x; }
static int thrice(int x) { return 3 * x; }
template <class U> U (*Q<U>::conv)(U) = nullptr;
template <class U> U Q<U>::k = 5;
template <> long (*Q<long>::conv)(long) = twice;
template <> int Q<int>::k = 7;
struct S { static int one(int n) { return n + 1; } static int k; };
int S::k = 3;
struct D : S { int extra; };
struct E : S { static int one(int n) { return n + 100; } };
struct F : S { int one(int n) { return n + 200; } };
struct A { int v; int w; int get() const { return v + w; } int twice() const { return 2 * v; } };
struct B { static int A::*pm; static int (A::*mf)() const; };
int A::*B::pm = &A::w;
int (A::*B::mf)() const = &A::get;
int main() {
  M m; m.v = 3; M *pm = &m;
  std::printf("%d %d %d %d %zu %d\n", M::pick(4), m.pick(5), pm->pick(6), M::tab[1](2) + m.tab[0](1), sizeof(M), m.v);
  std::printf("%.2f %.2f\n", M::avg(3, 1.0), m.avg(5));
  std::printf("%d %d %d %d\n", N::T::getp(0)(5), N::T::getp(1)(5), N::T::ref(7), (*N::T::getp(1))(2));
  Q<int>::conv = thrice;
  std::printf("%ld %d %ld %d\n", Q<long>::conv(21), Q<int>::conv(4), Q<long>::k, Q<int>::k);
  int (*d)(int) = &D::one; int (*e)(int) = D::one; int *pk = &D::k; int (*h)(int) = &E::one;
  std::printf("%d %d %d %d %d %d\n", d(1), e(2), *pk, D::one(3), h(1), d == &S::one);
  int (F::*fm)(int) = &F::one; F fo;
  std::printf("%d %d ", (fo.*fm)(1), F::S::one(1));
  A a = {4, 9}; A *pa = &a;
  std::printf("%d %d %zu ", a.*B::pm, (a.*B::mf)(), sizeof(B)); B::mf = &A::twice; B::pm = &A::v;
  std::printf("%d %d\n", (pa->*B::mf)(), pa->*B::pm);
  return 0;
}
