// a member of a class that is no POD is not packed in a packed struct (clang's rule since its ABI 16, but on Apple's
// platforms): it keeps its alignment unless the class or the member says packed; a POD class member is packed
#include <cstddef>
#include <cstdio>
#include <string>
struct NP { NP() {} int v = 1; };
struct POD { int v; };
struct __attribute__((packed)) PNP { char c; int v; PNP() : c(0), v(5) {} };
struct __attribute__((packed)) H1 { char c; NP n; };
struct __attribute__((packed)) H2 { char c; POD p; };
struct __attribute__((packed)) H3 { char c; NP n __attribute__((packed)); };
struct __attribute__((packed)) H4 { char c; PNP q; };
struct __attribute__((packed)) H5 { char c; NP a[2]; };
struct __attribute__((packed)) H6 { char c; std::string s; };
#ifdef __APPLE__
enum { H1_SIZE = 5, H1_AT = 1, H6_SIZE = 25, H6_AT = 1 };   // Apple's platforms keep packing a non-POD member (0.250)
#else
enum { H1_SIZE = 8, H1_AT = 4, H6_SIZE = 32, H6_AT = 8 };
#endif
int main() {
  std::printf("%d %d\n", (int) (sizeof(H1) == H1_SIZE), (int) (offsetof(H1, n) == H1_AT));
  std::printf("%zu %zu\n", sizeof(H2), offsetof(H2, p));
  std::printf("%zu %zu\n", sizeof(H3), offsetof(H3, n));
  std::printf("%zu %zu\n", sizeof(H4), offsetof(H4, q));
  std::printf("%zu %zu\n", sizeof(H5), offsetof(H5, a));
  std::printf("%d %d\n", (int) (sizeof(H6) == H6_SIZE), (int) (offsetof(H6, s) == H6_AT));
  H1 h; H6 s6; s6.s = "packed";
  std::printf("%d %s\n", h.n.v, s6.s.c_str());
  return 0;
}
