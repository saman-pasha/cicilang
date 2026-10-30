// refused (0.238): a block given back twice -- `use after move'
#include <memory>
int main() {
  std::allocator<int> a;
  own int *p = a.allocate(2);
  p[0] = 3;
  a.deallocate(p, 2);
  a.deallocate(p, 2);
  return 0;
}
