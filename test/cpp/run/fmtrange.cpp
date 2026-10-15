// C++23's range formatting ([format.range]): a vector, a map, a vector of strings (debug-formatted) and a nested format
// spec. format_kind<R> is a lambda called in place, the map's specialization is named `range_format::map', and the
// retargeted format context's lambda deduces its result from a decltype(auto) visit. (The pair and the tuple are
// fmttuple.cpp: together they passed the instantiation budget over libc++ 18.)
#include <format>
#include <map>
#include <string>
#include <vector>
#include <cstdio>
int main() {
  std::vector<int> v{1, 2, 3};
  std::map<std::string, int> m{{"a", 1}, {"b", 2}};
  std::vector<std::string> w{"x", "y"};
  std::printf("%s|%s|%s|%s\n", std::format("{}", v).c_str(), std::format("{}", m).c_str(), std::format("{}", w).c_str(),
              std::format("{::02}", v).c_str());
  return 0;
}
