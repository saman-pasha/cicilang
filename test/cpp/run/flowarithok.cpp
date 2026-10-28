// what a function stores of a value computed from its pointer parameter, kept while the pointee lives: built (0.221)
#include <cstdio>
#include <vector>
struct S { int v; };
void put(std::vector<int *> &out, S *p) { out.push_back(&p->v); }
void put2(std::vector<int *> &out, int *p) { out.push_back(p + 1); }
int main() {
  S s{4}; int a[2] = {5, 6};
  std::vector<int *> out;
  put(out, &s); put2(out, a);
  std::printf("%d %d\n", *out[0], *out[1]);
}
