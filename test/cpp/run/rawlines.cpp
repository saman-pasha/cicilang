// Raw string literals that span lines (0.138): the preprocessor keeps each one as one token, its newlines, a quote and a
// `//' inside it, and the lines after it keep their numbers.
#include <cstdio>
int main() {
  const char *a = R"(one
two "q" // not a comment
three)";
  const char *b = R"x(a)" b
c)x"; int n = 1'000; const char *c = "R\"("; const char *d = u8R"(e
f)";
  std::printf("%s|%s|%d|%s|%s\n", a, b, n, c, d);
  return __LINE__;
}
