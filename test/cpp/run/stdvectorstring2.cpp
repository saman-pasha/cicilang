// vector<string>: insert at a position and a range, erase one and a range, resize up and down, assign, the strings kept
#include <vector>
#include <string>
#include <cstdio>
int main() {
  std::vector<std::string> v = {"alpha", "beta", "gamma"};
  v.insert(v.begin() + 1, "inserted-and-long-enough-to-leave-the-short-buffer");
  std::vector<std::string> more = {"x", "y"};
  v.insert(v.end(), more.begin(), more.end());
  v.erase(v.begin());
  v.erase(v.begin() + 1, v.begin() + 3);
  v.resize(5, "fill");
  v.resize(4);
  for (const auto &s : v) std::printf("%s|", s.c_str());
  std::printf("\n%d\n", (int) v.size());
  v.assign(2, "z");
  std::printf("%s %s %d\n", v[0].c_str(), v[1].c_str(), (int) v.size());
  return 0;
}
