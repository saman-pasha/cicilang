// what the flows let through (0.217): a function keeping its parameter in a global vector and in a static local one,
// given static storage's address, through another function too; a view member set by a member from a view of a string
// that outlives the object's use, and of a static string, the object returned; a vector by reference given a local's
// address, used while the local lives
#include <cstdio>
#include <string>
#include <string_view>
#include <vector>
static int k = 5;
static std::string gs = "a string long enough to live on the heap";
std::vector<int *> g;
void reg(int *p) { g.push_back(p); }
void fwd(int *p) { reg(p); }
std::size_t keep(int *p) { static std::vector<int *> all; all.push_back(p); return all.size(); }
struct V { std::string_view sv; void set(std::string_view v) { sv = v; } };
void put(std::vector<int *> &v, int *p) { v.push_back(p); }
V globalview() { V w; w.set(gs); return w; }
int main() {
  int x = 1;
  reg(&k);
  fwd(&k);
  std::size_t n = keep(&k);
  std::string s = "local";
  V w;
  w.set(s);
  std::vector<int *> v;
  put(v, &x);
  std::printf("%zu %d %zu %zu %zu %d %zu\n", g.size(), *g[1], n, w.sv.size(), globalview().sv.size(), *v[0], v.size());
  return 0;
}
