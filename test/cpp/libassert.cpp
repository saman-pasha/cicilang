// a library header's static assertion is asked (0.221): std::get<5> of a std::array<int, 3> read past the array's end, where
// clang++ refuses it with libc++'s "Index out of bounds in std::get<> (std::array)"
#include <array>
int main() {
  std::array<int, 3> a{};
  return std::get<5>(a);
}
