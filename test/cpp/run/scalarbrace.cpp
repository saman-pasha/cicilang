// A scalar member's braced default initializer is its one item, whatever names its type: libc++'s basic_format_args
// writes `size_t __size_{0};' beside `basic_format_args() noexcept = default;'.
#include <cstdio>
#include <cstddef>
template <class T> struct Args {
  using sz = std::size_t;
  Args() noexcept = default;
  std::size_t size_{3};
  sz count_{};
  T value_{7};
};
int main() {
  Args<long> a;
  std::printf("%d %d %d\n", (int) a.size_, (int) a.count_, (int) a.value_);
  return 0;
}
