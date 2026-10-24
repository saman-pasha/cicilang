#include <cstdio>
#include <memory_resource>
#include <string>
#include <vector>
// std::pmr: a monotonic buffer resource under pmr containers
int main() {
  char buf[1024];
  std::pmr::monotonic_buffer_resource mr(buf, sizeof buf);
  std::pmr::vector<int> v(&mr);
  for (int i = 0; i < 10; i++) v.push_back(i * i);
  std::pmr::string s("hello", &mr);
  s += " world";
  std::printf("%d %d %s %zu\n", v[3], v[9], s.c_str(), s.size());
  std::pmr::vector<std::pmr::string> names(&mr);
  names.emplace_back("ann");
  names.emplace_back("bob");
  std::printf("%s %s %d\n", names[0].c_str(), names[1].c_str(), (int) (names.get_allocator().resource() == &mr));
  std::pmr::unsynchronized_pool_resource pool;
  std::pmr::vector<long> w(&pool);
  w.assign(5, 7);
  std::printf("%ld %zu\n", w[4], w.size());
  return 0;
}
