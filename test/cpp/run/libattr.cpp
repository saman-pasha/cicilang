// libc++'s roads that __has_attribute opens (0.221): std::string's packed size words, the stream's fill, nothrow new
#include <cstdio>
#include <iomanip>
#include <new>
#include <sstream>
#include <string>
int main() {
  std::string s = "short", l(40, 'x');
  l += s;
  std::ostringstream o;
  o << std::setfill('*') << std::setw(6) << 42 << '|' << std::left << std::setw(4) << 7 << '|';
  int *p = new (std::nothrow) int(9);
  std::printf("%zu %zu %s %d %zu\n", s.size(), l.size(), o.str().c_str(), *p, sizeof(std::string));
  delete p;
  return 0;
}
