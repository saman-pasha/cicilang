// a library header's static assertion is asked (0.221): a variant with a void alternative, which compiled
#include <variant>
int main() {
  std::variant<int, void> v;
  return 0;
}
