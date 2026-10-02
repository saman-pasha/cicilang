// std::quoted on output and on input, with the default delimiter and escape and with others
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
int main() {
  std::cout << std::quoted("hello \"world\"") << '\n';
  std::cout << std::quoted(std::string("a'b"), '\'', '\\') << '\n';
  std::istringstream in("\"two words\" next");
  std::string s, t; in >> std::quoted(s) >> t;
  std::cout << s << '|' << t << '\n';
  return 0;
}
