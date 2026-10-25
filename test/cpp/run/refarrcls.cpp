// a braced argument to a reference to an array of class objects: a temporary array, its elements built in order and
// destroyed at the end of the full-expression, the last first
#include <array>
#include <cstdio>
#include <string>
struct T { int v; T(int x) : v(x) { std::printf("T(%d) ", v); } ~T() { std::printf("~T(%d) ", v); } };
int sum(const T (&a)[3]) { return a[0].v + a[1].v + a[2].v; }
int len(std::string (&&a)[2]) { return (int) (a[0].size() + a[1].size()); }
int main() {
  std::printf("[%d]\n", sum({1, 2, 3}));
  std::printf("[%d]\n", len({"ab", "cde"}));
  auto a = std::to_array<std::string>({"x", "yy", "zzz"});
  std::printf("%zu %s %s\n", a.size(), a[1].c_str(), a[2].c_str());
  return 0;
}
