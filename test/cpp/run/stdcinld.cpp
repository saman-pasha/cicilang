// cin >> long double, and the stream's state after a value that does not read
#include <cstdio>
#include <iostream>
int main() {
  long double a = 0, b = 0, c = 0;
  std::cin >> a >> b;
  std::printf("%.4Lf %.1Lf %.4Lf\n", a, b, a + b);
  std::cin >> c;
  std::printf("%d %.1Lf\n", (int) std::cin.fail(), c);
  return 0;
}
