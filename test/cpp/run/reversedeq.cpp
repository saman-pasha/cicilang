// C++20's reversed == candidate ([over.match.oper]/3.4.4): only operator==(const C *, End) is written, and
// `End{} == p' and `End{} != p' take it reversed, as libc++ 18's sentinel_for<__nul_terminator, const char *> asks
#include <cstdio>
struct End {};
template <class C> bool operator==(const C *p, End) { return *p == C('\0'); }
struct Box { int v; bool operator==(int x) const { return v == x; } };
template <class S, class I> concept sentinel_like = requires(S s, I i) { s == i; i == s; s != i; };
int main() {
  const char *s = "ab";
  int n = 0;
  while (!(End{} == s)) { ++s; ++n; }
  std::printf("%d %d %d\n", n, End{} != s, (int) sentinel_like<End, const char *>);
  Box b{7};
  std::printf("%d %d %d\n", 7 == b, 8 != b, b == 7);
  return 0;
}
