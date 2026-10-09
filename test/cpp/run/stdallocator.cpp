#include <memory>
#include <cstdio>
int main() {
  std::allocator<int> a;
  int *p = a.allocate(4);
  for (int i = 0; i < 4; i++) p[i] = i * i;
  std::printf("%d %d\n", p[2], p[3]);
  a.deallocate(p, 4);
  std::allocator<long> b;
  using AT = std::allocator_traits<std::allocator<long>>;
  long *q = AT::allocate(b, 3);
  q[0] = 5; q[2] = 7;
  std::printf("%ld %ld\n", q[0], q[2]);
  AT::deallocate(b, q, 3);
  return 0;
}
