// Padding on an ostream: the ostreambuf_iterator overload of __pad_and_output is the more specialized one.
#include <iomanip>
#include <iostream>
int main() {
  std::cout << std::setw(6) << "ab" << '|' << std::setw(4) << 7 << '|' << std::left << std::setw(5) << "cd" << "|\n";
  return 0;
}
