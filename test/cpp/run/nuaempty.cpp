// An empty data member is no data (0.198; the Itanium ABI's term, [meta.unary.prop]'s is_empty): a class whose members are all
// [[no_unique_address]] members of empty classes is empty itself -- as a member, as a base, to is_empty -- and an empty subobject
// inside such a member is in the way of another of its type, as clang++ lays them
#include <cstdio>
#include <cstddef>
#include <type_traits>
struct E {};
struct H { [[no_unique_address]] E e; };
struct H2 { [[no_unique_address]] H h; };
struct P { [[no_unique_address]] H2 h; int *p; };
struct Q { int *p; [[no_unique_address]] H2 h; };
struct R { [[no_unique_address]] H a; [[no_unique_address]] H b; };
struct S : H { int x; };
struct T { [[no_unique_address]] E e; [[no_unique_address]] H h; };
struct U { [[no_unique_address]] H h; [[no_unique_address]] E e; };
struct V { [[no_unique_address]] H h; int x; };
int main() {
  std::printf("%zu %zu %zu %zu %zu %zu %zu %zu %zu\n", sizeof(H), sizeof(H2), sizeof(P), sizeof(Q), sizeof(R), sizeof(S), sizeof(T), sizeof(U), sizeof(V));
  P p{{}, nullptr};
  Q q{nullptr, {}};
  T t{};
  U u{};
  std::printf("%d %d %d %d %d %d\n", (int) ((char *) &p.h - (char *) &p), (int) ((char *) &q.h - (char *) &q), (int) offsetof(R, b),
              (int) ((char *) &t.h - (char *) &t), (int) ((char *) &u.e - (char *) &u), (int) offsetof(V, x));
  std::printf("%d %d %d %d %d\n", (int) std::is_empty_v<H>, (int) std::is_empty_v<H2>, (int) std::is_empty_v<P>, (int) std::is_empty_v<E>, (int) std::is_empty_v<S>);
}
