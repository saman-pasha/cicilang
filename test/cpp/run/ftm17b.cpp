// libc++'s C++17 facilities by their feature-test macros, the second part (0.206): the non-member size, data, empty and
// reverse iterators, shared_ptr of an array, is_null_pointer and is_final, a recursive class's implicit copy made once,
// an initializer_list of objects built in place, the scans and transform_reduce, for_each_n, aligned_alloc and
// timespec_get.
#include <algorithm>
#include <cstddef>
#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <ctime>
#include <iterator>
#include <list>
#include <map>
#include <memory>
#include <numeric>
#include <string>
#include <type_traits>
#include <vector>

struct Node {
  int v;
  std::vector<Node> kids;
  std::list<Node> more;
  std::map<int, Node> byid;
};
struct Fin final {};
struct Base { virtual ~Base() = default; };

int count(const Node &n) {
  int c = 1;
  for (const Node &k : n.kids) c += count(k);
  return c;
}

int main() {
  int arr[4] = {1, 2, 3, 4};
  std::vector<int> v{7, 8};
  std::printf("access %zu %d %d %d %d\n", std::size(arr), *std::data(v), (int) std::empty(v), *std::rbegin(arr), *std::crbegin(v));
  std::shared_ptr<int[]> sp(new int[3]{5, 6, 7});
  sp[1] = 60;
  std::shared_ptr<int[4]> sq(new int[4]{0, 0, 0, 8});
  std::printf("shared_array %d %d %d\n", sp[0], sp[1], sq[3]);
  std::printf("traits %d %d %d %d\n", (int) std::is_null_pointer_v<decltype(nullptr)>, (int) std::is_null_pointer_v<void *>,
              (int) std::is_final_v<Fin>, (int) std::is_final_v<Base>);
  Node root{1, {Node{2, {}, {}, {}}, Node{3, {Node{4, {}, {}, {}}}, {}, {}}}, {}, {}};
  root.more.push_back(Node{5, {}, {}, {}});
  root.byid[9] = Node{6, {}, {}, {}};
  std::printf("recursive %d %zu %d\n", count(root), root.more.size(), root.byid[9].v);
  std::vector<int> in{1, 2, 3, 4}, ex(4), inc(4), tex(4);
  std::exclusive_scan(in.begin(), in.end(), ex.begin(), 10);
  std::inclusive_scan(in.begin(), in.end(), inc.begin());
  std::transform_exclusive_scan(in.begin(), in.end(), tex.begin(), 0, std::plus<>{}, [](int x) { return x * x; });
  std::printf("scan %d %d %d %d %d %d\n", ex[0], ex[3], inc[3], tex[1], tex[3],
              std::transform_reduce(in.begin(), in.end(), in.begin(), 0));
  int total = 0;
  std::for_each_n(in.begin(), 3, [&](int x) { total += x; });
  std::printf("for_each_n %d\n", total);
  void *al = std::aligned_alloc(64, 128);
  std::printf("aligned_alloc %d\n", (int) (reinterpret_cast<std::uintptr_t>(al) % 64 == 0));
  std::free(al);
  std::timespec ts;
  std::printf("timespec_get %d\n", (int) (std::timespec_get(&ts, TIME_UTC) == TIME_UTC && ts.tv_sec > 0));
}
