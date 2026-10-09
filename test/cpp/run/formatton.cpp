// std::format_to_n over a plain pointer and std::formatted_size, with <string> read before <format> (C++20). Reading both headers declares a library
// function template twice (each header's summary holds it): libc++ 21's format machinery calls `std::back_inserter(*__container_)' inside a class it only
// names (`__container_inserter_buffer<char *, char>' over a `void *'), the first candidate refuses and leaves `back_insert_iterator<void>' half made, and the
// second, answered its name, held and emitted a constructor of a class that was never made. Two copies of one function template are one candidate.
// `std::addressof' in a base initializer is typed by the callee's own parameter, not by a typedef some other function declares in a block.
#include <cstdio>
#include <format>
#include <string>
int main() {
  char buf[8] = {};
  auto r = std::format_to_n(buf, 5, "{}", 1234567);
  std::printf("%.5s %td\n", buf, r.size);
  std::printf("%zu\n", std::formatted_size("{:>6}", 42));
  std::string s = std::format("{:>4}|{:<4}|", 7, 8);
  std::printf("%s\n", s.c_str());
  return 0;
}
