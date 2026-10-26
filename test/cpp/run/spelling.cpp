#include <cstdio>
// a token's spelling in #x ([cpp.stringize]/2): an alternative token, a raw string, a literal as written, a digraph
// as written; 0.210 spelled the punctuator, the literal's value
#define S(...) #__VA_ARGS__
#define XS(...) S(__VA_ARGS__)
#define AND a and b
int main() {
  std::puts(S(a and b or not c bitand d bitor compl e xor f and_eq or_eq xor_eq not_eq));
  std::puts(S(R"(a\b)" R"x(q"z)x" u8R"(r)" LR"(w)" uR"(v)" UR"(t)"));
  std::puts(S('ab' "\x41" <: :> <% %> %:));
  std::puts(XS(AND));
  bool a = true, b = false;
  int v<:2:> = <% 1, 2 %>;
  std::printf("%d %d %d %s\n", a and not b, compl 0, v<:1:>, R"(x\ny)");
  return 0;
}
