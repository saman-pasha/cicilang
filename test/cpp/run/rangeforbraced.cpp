// a range-for over a braced list (0.117, [stmt.ranged]: for-range-initializer is an expression or a braced-init-list): the list
// is the backing array of the initializer_list it would make -- ints, strings, doubles, variables and sums among them, an
// rvalue-reference declaration, and C++20's init-statement before the declaration
#include <cstdio>
#include <string>
int main() {
  for (int v : {4, 9, 1, 7}) std::printf("%d ", v);
  std::printf("\n");
  for (const char *s : {"ab", "cd"}) std::printf("%s ", s);
  for (auto d : {1.5, 2.5}) std::printf("%.1f ", d);
  int a = 3, b = 5;
  for (int x : {a, b, a + b}) std::printf("%d ", x);
  for (auto &&x : {10, 20}) std::printf("%d ", x);
  std::printf("\n");
  for (int i = 0; int x : {1, 2, 3}) { i++; std::printf("%d:%d ", i, x); }
  std::printf("\n");
  return 0;
}
