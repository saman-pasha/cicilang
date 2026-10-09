// std::deque (0.117): four defects stood between libc++'s deque and a run. `__deque_iterator::__block_size' is a static of a class template
// DEFINED OUT OF ITS CLASS (`template <...> const _DiffType __deque_iterator<...>::__block_size = ...;'), undefined at the link; `deque::end()' passes
// `__map_.empty() ? 0 : *__mp + ...' to an iterator taking a pointer, and the conditional with the literal zero was typed int -- the pointer went through
// `ptrtoint ... to i32' and lost its high half (a crash at the first push_back); the same conditional chose no constructor; and a `const size_t &' handed
// an int (`std::max<size_t>(2 * __map_.capacity(), 1)') read eight bytes of a four-byte temporary, so the map asked to grow by 8589934593 pointers
// (refwiden.cpp). push and pop at both ends, indexing, iteration, insert, erase, copy, resize, comparison
#include <cstdio>
#include <deque>
#include <string>
int main() {
  std::deque<int> d;
  for (int i = 0; i < 10; i++) {
    if (i % 2) d.push_back(i);
    else d.push_front(i);
  }
  std::printf("%zu %d %d %d\n", d.size(), d.front(), d.back(), d[4]);
  d.pop_front();
  d.pop_back();
  int s = 0;
  for (int x : d) s += x;
  std::printf("%zu %d\n", d.size(), s);
  d.insert(d.begin() + 2, 99);
  d.erase(d.begin());
  std::printf("%d %zu\n", d[1], d.size());
  std::deque<int> e(d);
  e.resize(3);
  std::printf("%zu %d\n", e.size(), (int)(e == d));
  for (int i = 0; i < 3000; i++) e.push_back(i);
  std::printf("%zu %d %d\n", e.size(), e[1500], e.back());
  std::deque<std::string> w;
  w.push_back("b");
  w.push_front("a");
  w.emplace_back("c");
  for (const std::string &x : w) std::printf("%s ", x.c_str());
  std::printf("\n");
  e.clear();
  std::printf("%d\n", (int)e.empty());
  return 0;
}
