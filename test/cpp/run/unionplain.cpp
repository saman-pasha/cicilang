// a plain union named by its bare name is a union ([class.union]): its size the largest member's; a union with constructors
// under [[no_unique_address]] lends no tail padding, its data size its size
#include <cstddef>
#include <cstdio>
union P { int i; char c; };
union U { int i; char c; U() {} ~U() {} };
union V { char c; int i; V() {} };
struct X1 { U f; bool s; };
struct X2 { [[no_unique_address]] U f; bool s; };
struct X3 { [[no_unique_address]] P f; bool s; };
struct Y { [[no_unique_address]] V f; [[no_unique_address]] char s; };
struct W { char c; int i; W() {} };
struct Z { [[no_unique_address]] W f; char s; };
int main() {
  P p;
  p.i = 0x4142;
  std::printf("%d %d %d %d %d\n", (int) sizeof(P), (int) alignof(P), (int) sizeof(U), (int) sizeof(X1), (int) offsetof(X1, s));
  std::printf("%d %d %d %d\n", (int) sizeof(X2), (int) offsetof(X2, s), (int) sizeof(X3), (int) offsetof(X3, s));
  std::printf("%d %d %d %d %c\n", (int) sizeof(Y), (int) offsetof(Y, s), (int) sizeof(Z), (int) offsetof(Z, s), p.c);
  return 0;
}
