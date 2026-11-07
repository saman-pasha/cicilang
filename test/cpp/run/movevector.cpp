// a class of the program whose copy is deleted moves through std::vector and std::optional (0.258)
#include <cstdio>
#include <optional>
#include <vector>
#include <memory>
struct NC { int k; NC(int x) : k(x) {} NC(const NC &) = delete; NC(NC &&) = default; };
int main() {
  std::vector<NC> v; v.emplace_back(1); v.push_back(NC(3)); v.reserve(10); NC b(4); v.push_back(std::move(b));
  std::optional<NC> o; o.emplace(5); std::optional<NC> o2 = std::move(o);
  std::vector<std::unique_ptr<int>> u; u.push_back(std::make_unique<int>(6)); u.emplace_back(new int(7)); u.reserve(8);
  std::printf("%zu %d %d %d %d\n", v.size(), v[1].k, v[2].k, o2->k, *u[0] + *u[1]);
}
