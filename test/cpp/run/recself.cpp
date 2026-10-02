// a recursive lambda through an explicit object parameter, its result deduced from the first return
#include <cstdio>
int main() {
  auto fact = [](this auto self, int n) { if (n <= 1) return 1; return n * self(n - 1); };
  auto fib = [](this auto const &self, int n) -> long { return n < 2 ? n : self(n - 1) + self(n - 2); };
  std::printf("%d %ld\n", fact(5), fib(20));
  return 0;
}
