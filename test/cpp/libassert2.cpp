// a library header's static assertion is asked (0.221): an optional of a reference, which compiled
#include <optional>
int main() {
  std::optional<int &> o;
  return o ? 1 : 0;
}
