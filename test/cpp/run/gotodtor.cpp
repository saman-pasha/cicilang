// A goto destroys the objects of the scopes it leaves ([stmt.jump]/2): out of a loop's body and a block, and back past
// a declaration in its label's own block; a std::string built in a loop of gotos.
#include <cstdio>
#include <string>
struct Loud {
  int n;
  Loud(int k) : n(k) { std::printf("make %d\n", n); }
  ~Loud() { std::printf("drop %d\n", n); }
};
int f(int k) {
  {
    Loud a(1);
    for (int i = 0; i < 3; i++) {
      Loud b(10 + i);
      if (i == k) goto out;
    }
  }
out:
  std::printf("out\n");
  int n = 0;
again:
  Loud c(100 + n);
  if (++n < 3) goto again;
  return n;
}
int main() {
  std::printf("%d\n", f(1));
  std::string s = "x";
  int i = 0;
loop:
  s += "y";
  if (++i < 3) goto loop;
  std::printf("%s\n", s.c_str());
  return 0;
}
