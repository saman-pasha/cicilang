// A class of the program over an abstract class the library ships, with no destructor of its own, is destroyed by the
// base's base-object destructor, D2, as clang destroys it: a Mac's libc++ makes the complete-object one, D1, of an
// abstract class a trap (0.252).
#include <cstdio>
#include <memory_resource>
#include <string>
#include <system_error>
#include <vector>
struct counting : std::pmr::memory_resource {
  int n = 0;
  void *do_allocate(std::size_t b, std::size_t a) override { n++; return std::pmr::new_delete_resource()->allocate(b, a); }
  void do_deallocate(void *p, std::size_t b, std::size_t a) override { std::pmr::new_delete_resource()->deallocate(p, b, a); }
  bool do_is_equal(const std::pmr::memory_resource &o) const noexcept override { return this == &o; }
};
struct mine : std::error_category {
  const char *name() const noexcept override { return "mine"; }
  std::string message(int c) const override { return c == 1 ? "one" : "other"; }
};
int main() {
  {
    counting r;
    std::pmr::vector<int> v(&r);
    for (int i = 0; i < 5; i++) v.push_back(i);
    std::printf("%d %zu\n", (int) (r.n > 0), v.size());
  }
  {
    mine c;
    std::error_code e(1, c);
    std::printf("%s %s %d\n", c.name(), e.message().c_str(), e.value());
  }
  std::puts("done");
  return 0;
}
