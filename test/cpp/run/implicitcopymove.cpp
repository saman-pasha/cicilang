// the implicit copy and move of a class made apart, the one made first never standing for the other
#include <cstdio>
#include <string>
#include <utility>
#include <vector>
struct S {
  std::string s;
  std::vector<int> v;
};
struct D {   // a destructor declared: no implicit move, an rvalue takes the copy
  std::string s;
  ~D() {}
};
int main() {
  S a{"alpha", {1, 2, 3}};
  S b = a;
  S c = std::move(a);
  S d = b;
  S e = std::move(d);
  std::printf("[%s] %zu [%s] %zu [%s] %zu [%s] %zu\n", a.s.c_str(), a.v.size(), b.s.c_str(), b.v.size(), c.s.c_str(), c.v.size(), e.s.c_str(), e.v.size());
  D x{"delta"};
  D y = std::move(x);
  D z = x;
  std::printf("[%s] [%s] [%s]\n", x.s.c_str(), y.s.c_str(), z.s.c_str());
  return 0;
}
