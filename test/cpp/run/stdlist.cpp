// std::list (0.117): libc++'s `list' derives from `__list_imp', whose registration names `__list_node_base<int, void *>' and, through its
// pointer traits, `__list_node<int, void *>' -- an instance whose BASE is the class still being registered (C++ asks no definition of a pointee).
// The registration of the derived instance now waits for its base ('$cpp_deferred'). sort, merge, splice, reverse, unique, remove, push and pop at
// both ends, insert and erase through iterators, assign, resize, swap, a comparison. `assign(3, 4)' did not finish in 28 minutes: `insert(__e, __n, __x)'
// inside it asks the template `insert(const_iterator, _InpIter, _InpIter, __enable_if_t<__has_input_iterator_category<_InpIter>::value> * = 0)' with
// `_InpIter = size_t'; the typedef `size_t' kept its name in the path (`size_t::iterator_category' found some other class's typedef) and the defaulted
// last parameter, which the call leaves out, was never substituted -- the SFINAE held, and the rejection came by ranking after 400,000 flattened names
#include <cstdio>
#include <list>
#include <string>
int main() {
  std::list<int> a = {5, 3, 9, 1}, b = {4, 2};
  a.sort();
  b.sort();
  a.merge(b);
  for (int x : a) std::printf("%d ", x);
  std::printf("| %zu %zu\n", a.size(), b.size());
  a.push_front(0);
  a.push_back(10);
  a.remove(3);
  a.reverse();
  a.unique();
  std::list<int> c;
  c.splice(c.begin(), a, a.begin());
  for (int x : a) std::printf("%d ", x);
  std::printf("| %d %zu\n", c.front(), c.size());
  auto it = a.begin();
  ++it;
  ++it;
  a.insert(it, 77);
  a.erase(a.begin());
  for (auto i = a.rbegin(); i != a.rend(); ++i) std::printf("%d ", *i);
  std::printf("| %d %d\n", a.front(), a.back());
  a.pop_front();
  a.pop_back();
  a.resize(6, 8);
  std::list<int> d;
  d.assign(3, 4);
  d.swap(a);
  std::printf("%zu %zu %d %d\n", a.size(), d.size(), (int)(a == d), (int)a.empty());
  std::list<std::string> s;
  s.push_back("one");
  s.emplace_back("two");
  s.push_front("zero");
  for (const std::string &x : s) std::printf("%s ", x.c_str());
  std::printf("\n");
  s.clear();
  std::printf("%d\n", (int)s.empty());
  return 0;
}
