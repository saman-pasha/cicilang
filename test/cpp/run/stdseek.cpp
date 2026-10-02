// seekg and tellg on a std::istringstream, seekp and tellp on a std::ostringstream
#include <cstdio>
#include <sstream>
#include <string>
int main() {
  std::istringstream in("hello world");
  in.seekg(6);
  std::string w;
  in >> w;
  std::printf("%s %ld\n", w.c_str(), (long) in.tellg());
  in.clear();
  in.seekg(-5, std::ios_base::end);
  char c = 0;
  in.get(c);
  std::printf("%c %ld\n", c, (long) in.tellg());
  in.seekg(0, std::ios_base::beg);
  in >> w;
  std::printf("%s\n", w.c_str());
  std::ostringstream out("hello world");
  out.seekp(0);
  out << "J";
  std::printf("%s %ld\n", out.str().c_str(), (long) out.tellp());
  out.seekp(0, std::ios_base::end);
  out << "!";
  std::printf("%s\n", out.str().c_str());
  return 0;
}
