// An empty base lies at offset 0 and a member of its type, marked [[no_unique_address]] or plain, past it (0.199; Itanium 2.4 II.3)
#include <cstdio>
#include <cstddef>
struct E {};
struct F {};
struct G : E {};
struct X : E { [[no_unique_address]] E e; };
struct Y : E { [[no_unique_address]] E e; int k; };
struct Z : E { E e; };
struct W : E { int k; E e; };
struct V : E { E e; int k; };
struct U : E, F { [[no_unique_address]] F f; };
struct T : G { [[no_unique_address]] E e; };
struct S : E { [[no_unique_address]] F f; [[no_unique_address]] E e; };
struct R : E { virtual void v() {} [[no_unique_address]] E e; };
template <class C, class M> int off(M C::*pm) { C c; return (int) ((char *) &(c.*pm) - (char *) &c); }
int main() {
  std::printf("%zu %d | %zu %d %d | %zu %d | %zu %d | %zu %d %d\n", sizeof(X), off(&X::e), sizeof(Y), off(&Y::e), (int) offsetof(Y, k), sizeof(Z), off(&Z::e),
              sizeof(W), off(&W::e), sizeof(V), off(&V::e), (int) offsetof(V, k));
  std::printf("%zu %d | %zu %d | %zu %d %d | %zu %d\n", sizeof(U), off(&U::f), sizeof(T), off(&T::e), sizeof(S), off(&S::f), off(&S::e), sizeof(R), off(&R::e));
}
