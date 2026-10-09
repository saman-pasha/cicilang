// a parenthesized functional cast (0.117): `(T())' with T a typedef name was read as the cast `(T ())' to a function type, which found no operand
// (libc++'s `thread() : __t_((__libcpp_thread_t())) {}' stopped the read of <thread>), and `(std::vector<int>(n))' read the declarator `(n)'
// of a type-id, its name dropped (`std::vector<int> r((std::istream_iterator<int>(in)), std::istream_iterator<int>())')
#include <cstdio>
#include <vector>
typedef unsigned long T;
struct S { T t; S() : t((T())) {} };
int f() { T a = (T()); T b = (T(5)); return (int)(a + b); }
int main() {
  int n = 3;
  auto v = (std::vector<int>(n));
  auto w = (std::vector<int>((n)));
  std::printf("%d %zu %zu %zu\n", f(), v.size(), w.size(), (std::vector<int>(n)).size());
  S s;
  std::printf("%lu\n", (unsigned long)s.t);
  return 0;
}
