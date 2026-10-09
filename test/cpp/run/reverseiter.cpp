// C++20: std::reverse_iterator over a string's and a vector's iterator, and ranges::iter_move of it. libc++ 21 writes the poison pill of
// the customization point deleted, `void iter_move() = delete;' (libc++ 18: `void iter_move();'): a deleted function is a declaration of its name,
// else the unqualified `iter_move(...)' of the concept went to the OBJECT `ranges::iter_move' and its operator() asked the same concept without end
#include <cstdio>
#include <iterator>
#include <string>
#include <vector>
int main() {
  std::string s("abcd");
  std::reverse_iterator<std::string::iterator> r(s.end());
  std::printf("%c", *r);
  ++r;
  std::printf("%c", *r);
  std::vector<int> v{1, 2, 3};
  auto rv = std::make_reverse_iterator(v.end());
  int x = std::ranges::iter_move(rv);
  std::printf(" %d %d\n", x, (int) (r.base() - s.begin()));
  return 0;
}
