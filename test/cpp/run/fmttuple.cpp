// C++23's tuple formatting ([format.tuple]): a pair and a tuple. The tuple formatter holds its elements' formatters in a
// std::tuple, whose default constructor is a constructor template: the holder's implicit default constructor builds them.
#include <format>
#include <string>
#include <tuple>
#include <utility>
#include <cstdio>
int main() {
  std::printf("%s|%s\n", std::format("{}", std::pair<int, std::string>{1, "a"}).c_str(), std::format("{}", std::tuple<int, char>{3, 'x'}).c_str());
  return 0;
}
