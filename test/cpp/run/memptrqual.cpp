// What libc++ 18's __invoke asks of a pointer to a data member of a plain struct: is_base_of<T, T> holds for a plain struct (and
// not for a pointer to it), a detection of `*t' is false for an arithmetic type and true for a pointer and a class with operator*,
// and `x.*pm' is const for a const object and an xvalue for an rvalue one.
#include <cstdio>
#include <type_traits>
#include <utility>

struct Pt {
  int x;
  int y;
};
struct Box {
  int v;
  int operator*() const { return v; }
};

template <class T>
concept derefable = requires(T t) { *t; };

template <class A0>
int deref_value(A0 &&a0) { return *static_cast<A0 &&>(a0); }
template <class A0>
int arrow_member(A0 &&a0) { return static_cast<A0 &&>(a0)->y; }
template <class A0>
int index_value(A0 &&a0) { return static_cast<A0 &&>(a0)[1]; }

// the overload whose result type dereferences its argument, written as libc++ writes it (a LEADING decltype): a substitution failure for an arithmetic one
template <class F, class A0>
decltype((*std::declval<A0>()).*std::declval<F>()) pick(F f, A0 &&a0, int) { return (*static_cast<A0 &&>(a0)).*f; }
template <class F, class A0>
int pick(F, A0 &&, long) { return -1; }

int main() {
  std::printf("%d %d %d\n", (int)std::is_base_of<Pt, Pt>::value, (int)std::is_base_of<Pt, Pt *>::value, (int)std::is_base_of<Pt, const Pt>::value);
  std::printf("%d %d %d %d\n", (int)derefable<int>, (int)derefable<int *>, (int)derefable<Box>, (int)derefable<double>);
  using R1 = decltype(std::declval<Pt &>().*std::declval<int Pt::*>());
  using R2 = decltype(std::declval<const Pt &>().*std::declval<int Pt::*>());
  using R3 = decltype(std::declval<Pt &&>().*std::declval<int Pt::*>());
  using R4 = decltype(std::declval<const Pt *>()->*std::declval<int Pt::*>());
  std::printf("%d %d %d %d\n", (int)std::is_same<R1, int &>::value, (int)std::is_same<R2, const int &>::value, (int)std::is_same<R3, int &&>::value,
              (int)std::is_same<R4, const int &>::value);
  int arr[3] = {5, 6, 7};
  int *ip = arr;
  Pt p{3, 4};
  Pt *pp = &p;
  std::printf("%d %d %d\n", deref_value(ip), arrow_member(pp), index_value(ip));
  std::printf("%d %d\n", pick(&Pt::y, pp, 0), pick(&Pt::y, 5, 0));
  return 0;
}
