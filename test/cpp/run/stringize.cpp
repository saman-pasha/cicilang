// #x keeps a space only where white space stood between two tokens of the argument ([cpp.stringize]/2), an empty
// expansion's or argument's white space passed to the next token, a variadic argument's commas as they stood, C++20's
// #__VA_OPT__, and a literal in the argument spelled with its escapes once
#include <cstdio>
#include <string>
#include <string_view>
#define S(x) #x
#define XS(x) S(x)
#define SV(...) #__VA_ARGS__
#define SO(a, ...) #__VA_OPT__(a  __VA_ARGS__)
#define VO(a, ...) S(a __VA_OPT__(x)+)
#define E
#define F(x) x + 1
#define T2(x, y) S(x y)
#define G(x, y) S(x y+)
int main() {
  std::string a = SV(std::vector<int>  v{1,2});
  std::puts(a.c_str());
  std::string_view b = XS(F(2) E+b);
  std::printf("%s %zu\n", b.data(), b.size());
  std::puts(SV(x ,y, z));
  std::puts(SO(1, 2   3));
  std::printf("[%s]\n", SO(1));
  std::puts(VO(1));
  std::puts(G(a,));
  std::puts(XS(std::string("a b\t")));
  std::puts(T2(a, operator<=>));
  std::puts(S(a<b>c  ::  d));
  std::puts(S([&](int x) { return x; }));
  std::puts(S(  u8"u" L'w'  ));
  return 0;
}
