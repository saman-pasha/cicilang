#include <cstdio>
#include <forward_list>
#include <numbers>
#include <scoped_allocator>
#include <string>
#include <system_error>
#include <typeindex>
#include <typeinfo>
#include <unordered_map>
#include <vector>
// forward_list, numbers, scoped_allocator_adaptor, error_code, type_index
int main() {
  std::forward_list<int> fl{3, 1, 2};
  fl.push_front(5);
  fl.sort();
  fl.reverse();
  for (int x : fl) std::printf("%d ", x);
  std::printf("\n");
  fl.remove(2);
  fl.insert_after(fl.begin(), 9);
  for (int x : fl) std::printf("%d ", x);
  std::printf("\n");
  std::printf("%.5f %.5f %.5f\n", std::numbers::pi, std::numbers::e, std::numbers::sqrt2);
  std::vector<std::string, std::scoped_allocator_adaptor<std::allocator<std::string>>> vs;
  vs.emplace_back("abc");
  vs.push_back("de");
  std::printf("%s %zu\n", vs[0].c_str(), vs.size());
  std::error_code ec = std::make_error_code(std::errc::invalid_argument);
  std::printf("%d %d %s\n", ec.value(), (int) (ec == std::errc::invalid_argument), ec.category().name());
  std::error_condition cond = ec.default_error_condition();
  std::printf("%d\n", (int) (cond == std::errc::invalid_argument));
  std::unordered_map<std::type_index, int> m;
  m[std::type_index(typeid(int))] = 1;
  m[std::type_index(typeid(double))] = 2;
  std::printf("%d %d %zu\n", m[typeid(int)], m[typeid(double)], m.size());
  return 0;
}
