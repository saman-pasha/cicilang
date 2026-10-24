#include <cstdio>
#include <flat_map>
#include <flat_set>
#include <string>
// std::flat_map and std::flat_set (C++23, libc++ 21)
int main() {
  std::flat_map<int, std::string> m;
  m[3] = "c";
  m[1] = "a";
  m.emplace(2, "b");
  for (const auto &[k, v] : m) std::printf("%d=%s ", k, v.c_str());
  std::printf("\n");
  std::printf("%d %zu\n", (int) m.contains(2), m.size());
  m.erase(1);
  std::printf("%s %zu\n", m.begin()->second.c_str(), m.size());
  std::flat_set<int> s{5, 1, 3, 1};
  for (int x : s) std::printf("%d ", x);
  std::printf("%zu %d\n", s.size(), (int) s.contains(3));
  return 0;
}
