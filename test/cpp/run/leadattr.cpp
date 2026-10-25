#include <cstdio>
#include <cstddef>
struct A { char c; __attribute__((aligned(16))) int i; };
struct B { char c; [[gnu::aligned(16)]] int i; };
struct C { char c; int i __attribute__((aligned(16))); };
struct D { char c; __attribute__((aligned(8))) int a, b; };
int main() {
  std::printf("%d %d %d %d %d %d %d\n", (int) offsetof(A, i), (int) offsetof(B, i), (int) offsetof(C, i), (int) offsetof(D, a), (int) offsetof(D, b), (int) sizeof(A), (int) sizeof(D));
  return 0;
}
