// A temporary in a loop's condition or step is built and destroyed at every evaluation ([class.temporary]/4; 0.112)
#include <cstdio>
#include <string>
int made = 0, gone = 0;
struct Tag {
  int v;
  Tag(int k) : v(k) { ++made; }
  ~Tag() { ++gone; }
  bool ok() const { return v < 3; }
};
const char *words[] = {"a", "bb", "ccc", "end", "x"};
int main() {
  int i = 0;
  while (Tag(i).ok()) ++i;
  std::printf("%d %d %d\n", i, made, gone);
  int k = 0;
  while (std::string(words[k]) != "end") ++k;
  std::printf("%d\n", k);
  int n = 0;
  for (int j = 0; Tag(j).ok(); j = Tag(j + 1).v) ++n;
  std::printf("%d %d %d\n", n, made, gone);
  int d = 0;
  do { ++d; } while (Tag(d).v < 5);
  std::printf("%d %d %d\n", d, made, gone);
  return 0;
}
