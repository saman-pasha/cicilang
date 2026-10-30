// 0.238: an allocator's block is fresh memory -- `std::allocator<T>::allocate' and `allocator_traits<A>::allocate' answer
// a block the program owns until `deallocate' takes it back: an own pointer holds it, a plain one must be given back
#include <cstdio>
#include <memory>
int sum(int *p, int n) noexcept { int s = 0; for (int i = 0; i < n; i++) s += p[i]; return s; }
int main() {
  std::allocator<int> a;
  own int *p = a.allocate(4);
  for (int i = 0; i < 4; i++) p[i] = i + 1;
  std::printf("%d\n", sum(p, 4));
  a.deallocate(p, 4);
  using AT = std::allocator_traits<std::allocator<long>>;
  std::allocator<long> b;
  long *q = AT::allocate(b, 3);
  q[0] = 5; q[1] = 6; q[2] = 7;
  std::printf("%ld\n", q[0] + q[1] + q[2]);
  AT::deallocate(b, q, 3);
  return 0;
}
