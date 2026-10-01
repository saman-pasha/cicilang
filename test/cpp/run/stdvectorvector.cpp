// a vector of vectors: grown, nested push_back, iterated, copied and moved
#include <vector>
#include <cstdio>
int main() {
  std::vector<std::vector<int>> m;
  for (int i = 0; i < 4; i++) { m.push_back({}); for (int j = 0; j <= i; j++) m[i].push_back(i * 10 + j); }
  int sum = 0; for (const auto &row : m) for (int x : row) sum += x;
  std::vector<std::vector<int>> c = m; c[3][0] = 99;
  std::vector<std::vector<int>> mv = std::move(c);
  std::printf("%d %d %d %d %d %d\n", (int) m.size(), (int) m[3].size(), sum, m[3][0], mv[3][0], (int) c.size());
  m.erase(m.begin() + 1); m.resize(5);
  std::printf("%d %d %d\n", (int) m.size(), (int) m[1].size(), (int) m[4].size());
  return 0;
}
