// C++20's macro examples ([cpp.subst], [cpp.rescan], [cpp.concat]), each expansion printed through #x: __VA_OPT__ over
// an argument that expands to `(' and one of digraphs, over an empty expansion, pasted and stringized; a rescan's
// result as clang++ and g++ give it; `# ## #' through two arguments; a name its own expansion left unexpanded
#include <cstdio>
#define S_(...) #__VA_ARGS__
#define XS(...) S_(__VA_ARGS__)
#define LPAREN() (
#define G(Q) 42
#define F(R, X, ...) __VA_OPT__(G R X) )
#define F2(...) fn(0 __VA_OPT__(,) __VA_ARGS__)
#define EMP
#define H3(X, ...) #__VA_OPT__(X##X X##X)
#define H4(X, ...) __VA_OPT__(a X ## X) ## b
#define f(a) a*g
#define g(a) f(a)
#define hash_hash # ## #
#define mkstr(a) # a
#define in_between(a) mkstr(a)
#define join(c, d) in_between(c hash_hash d)
#define obj obj+1
#define id(v) v
int main() {
  int x = F(LPAREN(), 0, <:-);
  std::printf("%d\n", x);
  std::puts(XS(F2(EMP) F2(1, 2)));
  std::puts(H3(, 0));
  std::puts(XS(H4(, 1)));
  std::puts(XS(f(2)(9)));
  std::puts(join(x, y));
  std::puts(XS(id(obj)));
  return 0;
}
