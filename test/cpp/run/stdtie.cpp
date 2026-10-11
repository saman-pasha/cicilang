// A stream's tie (0.136): cin is tied to cout, so a read flushes cout first; a buffer that counts its syncs sees each one.
#include <iostream>
#include <streambuf>
#include <string>
struct Counting : std::streambuf {
  std::string text; int syncs = 0;
  int_type overflow(int_type c) override { if (c != traits_type::eof()) text.push_back((char) c); return c; }
  int sync() override { ++syncs; return 0; }
};
int main() {
  std::cout << "tied " << (std::cin.tie() == &std::cout) << "\n";
  Counting cb; std::ostream out(&cb);
  std::istream in(std::cin.rdbuf());
  in.tie(&out);
  out << "before";
  int x = 0; in >> x;
  out << " after " << x;
  int syncs = cb.syncs;
  in.tie(nullptr); int y = 0; in >> y;
  std::cout << cb.text << " | syncs " << syncs << " then " << cb.syncs << " | y " << y << "\n";
  return 0;
}
