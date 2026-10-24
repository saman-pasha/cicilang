#include <cstdio>
#include <mdspan>
// std::mdspan (C++23): extents, layouts, element access
int main() {
  int data[12];
  for (int i = 0; i < 12; i++) data[i] = i * 10;
  std::mdspan<int, std::extents<int, 3, 4>> m(data);
  std::printf("%d %d %d\n", (int) m.rank(), (int) m.extent(0), (int) m.extent(1));
  std::printf("%d %d %d\n", m[0, 0], m[1, 2], m[2, 3]);
  std::mdspan<int, std::dextents<int, 2>> d(data, 2, 6);
  std::printf("%d %d %d\n", (int) d.extent(0), (int) d.extent(1), d[1, 5]);
  std::mdspan<int, std::extents<int, 3, 4>, std::layout_left> l(data);
  std::printf("%d %d\n", l[1, 2], l[2, 0]);
  long s = 0;
  for (int i = 0; i < m.extent(0); i++)
    for (int j = 0; j < m.extent(1); j++) s += m[i, j];
  std::printf("%ld %d\n", s, (int) m.size());
  return 0;
}
