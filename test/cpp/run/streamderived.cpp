// a program class derived from std::ostream and from std::iostream over its own streambuf (0.117): the constructor of a class over a
// library DIAMOND (iostream's two paths share basic_ios) builds the shared base once and each path through its base-variant constructor.
#include <iostream>
#include <streambuf>
#include <string>
struct Up : std::streambuf {
  std::string got;
  int overflow(int c) override { if (c != EOF) got += (char)c; return c; }
};
struct Ostr : std::ostream { Up b; Ostr() : std::ostream(&b) {} };
struct Both : std::iostream { Up b; Both() : std::iostream(&b) {} };
int main() {
  Ostr o; o << "hello " << 5;
  std::cout << o.b.got << '\n';
  Both x; x << "z" << 12 << 'c';
  std::cout << x.b.got << '\n';
  std::ostream &r = x; r << "!";
  std::cout << x.b.got << '\n';
  return 0;
}
