// a variable template whose lambda holds a local struct: sizeof of it at compile time, [[no_unique_address]] in tail padding
#include <cstdio>
template <class First, class Second>
inline constexpr bool fits = []() {
  struct X {
    [[no_unique_address]] First f;
    [[no_unique_address]] Second s;
  };
  return sizeof(X) == sizeof(First);
}();
struct A { int i; char c; A() {} };
struct P { int i; char c; };
union U { int i; char c; U() {} ~U() {} };
int main() {
  std::printf("%d %d %d %d\n", (int) fits<A, char>, (int) fits<P, char>, (int) fits<int, char>, (int) fits<U, bool>);
  return 0;
}
