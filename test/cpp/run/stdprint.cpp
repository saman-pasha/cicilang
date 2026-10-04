// std::print and std::println (C++23)
#include <print>
int main() {
  std::print("{} + {} = ", 2, 3);
  std::println("{}", 2 + 3);
  std::println("{:>5}|{:<5}|", "ab", "cd");
  return 0;
}
