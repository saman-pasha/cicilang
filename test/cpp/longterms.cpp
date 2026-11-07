// Two library headers whose summaries each hold a term too long for a line, in the clause file beside them -- pair's tag
// in <utility>'s, tuple's in <tuple>'s -- read cold in a HOME of test/cpp.sh's own, then served from that summary
// directory moved to another HOME (0.259): no header is read again, and the binary prints `7 7'.
#include <cstdio>
#include <tuple>
#include <utility>
int main() {
  std::pair<int, int> p(3, 4);
  std::tuple<int, int, int> t(5, 6, 7);
  std::printf("%d %d\n", p.first + p.second, std::get<2>(t));
  return 0;
}
