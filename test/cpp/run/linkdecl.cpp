// A declaration directly contained in a linkage specification is extern for whether it defines ([dcl.link]/7; 0.215):
// `extern "C" int g;' declares g, which a later declaration defines, and `extern "C" int a, b = 2;' declares a and
// defines b, where the braced form's `int k;' defines k. Each such declaration was a definition, and `int g = 5;' g's
// second one
#include <cstdio>

extern "C" int g;
extern "C" int h = 3;
extern "C" int a, b = 2;
extern "C" {
int k;
extern int m;
}
extern "C" int twice(int);
int g = 5;
int a = 4;
int m = 7;
extern "C" int twice(int x) { return 2 * x; }
int main() {
  std::printf("%d %d %d %d %d %d %d\n", g, h, a, b, k, m, twice(21));
  return 0;
}
