// refused (0.238): a block an allocator hands out and nothing gives back -- `plain pointer not consumed'
#include <memory>
int main() {
  std::allocator<int> a;
  int *p = a.allocate(4);
  p[0] = 1;
  return p[0] - 1;
}
