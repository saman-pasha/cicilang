// libc++'s __invoke hands a std::string to the string_view of a transparent hash (0.221): `static_cast<_Fp &&>(__f)(static_cast<
// _Args &&>(__args)...)' calls the parameter `__f' by the road of a local object, which took no argument pass, and the IR cast the
// string's struct to the view's; the unordered containers' static assertion `__check_hash_requirements' makes that instance
#include <cstdio>
#include <functional>
#include <string>
#include <string_view>
#include <type_traits>
#include <unordered_map>
struct SHash {
  using is_transparent = void;
  std::size_t operator()(std::string_view s) const { return s.size(); }
};
struct SEq {
  using is_transparent = void;
  bool operator()(std::string_view a, std::string_view b) const { return a == b; }
};
int main() {
  std::string s = "hello";
  const std::string &cs = s;
  std::printf("invoke %zu %zu\n", std::invoke(SHash{}, s), std::invoke(SHash{}, cs));
  std::printf("invocable %d\n", (int) std::is_invocable_r_v<std::size_t, SHash, const std::string &>);
  std::unordered_map<std::string, int, SHash, SEq> um{{"alpha", 1}, {"beta", 2}};
  std::printf("lookup %d %zu\n", um.find("beta")->second, um.count("gamma"));
}
