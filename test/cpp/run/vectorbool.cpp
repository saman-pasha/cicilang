// std::vector<bool> (0.117): the specialization packs bits into words and hands out a PROXY (`__bit_reference') for an element. It
// declares `void swap(vector &)' AND `static void swap(reference, reference)', and a bare `swap(__v)' in `reserve' went out with a
// null `this' because the NAME has a static overload (segmentation fault on the first `reserve'); `count += v[i]' met
// `no_operator(+=)' (a built-in operator over a class with a conversion function). push_back, reserve, resize, flip, assign,
// insert and erase, the proxy, the range-for, a copy, a comparison, `swap'
#include <algorithm>
#include <cstdio>
#include <vector>
int main() {
  std::vector<bool> v;
  for (int i = 0; i < 10; i++) v.push_back(i % 3 == 0);
  int c = 0;
  for (size_t i = 0; i < v.size(); i++) c += v[i];
  std::printf("%zu %d %d %d\n", v.size(), c, (int)v[9], (int)v.front());
  v[1] = true;
  v.flip();
  c = 0;
  for (size_t i = 0; i < v.size(); i++) c += v[i];
  std::printf("%d %d\n", c, (int)v.back());
  v.reserve(200);
  std::printf("%d %zu\n", (int)(v.capacity() >= 200), v.size());
  v.resize(70, true);
  std::printf("%zu %ld\n", v.size(), (long)std::count(v.begin(), v.end(), true));
  std::vector<bool> w(v);
  w[69] = false;
  std::printf("%d %d\n", (int)(v == w), (int)(v != w));
  v.swap(w);
  std::printf("%d %d\n", (int)v[69], (int)w[69]);
  std::vector<bool>::swap(v[0], v[1]);
  std::printf("%d %d\n", (int)v[0], (int)v[1]);
  w.assign(5, true);
  w.insert(w.begin() + 2, false);
  w.erase(w.begin());
  std::printf("%zu", w.size());
  for (bool b : w) std::printf(" %d", (int)b);
  std::printf("\n");
  w.pop_back();
  w.emplace_back(false);
  w.clear();
  std::printf("%d %zu\n", (int)w.empty(), w.size());
  return 0;
}
