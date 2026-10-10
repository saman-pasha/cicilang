// THE `overloaded' IDIOM (0.121): a class template deriving from a pack of lambdas, `struct overloaded : Ts... { using Ts::operator()...; }',
// built from a braced list -- an AGGREGATE WITH BASES (C++17, [dcl.init.aggr]/4.2: each base from the next item, in order; a closure with no
// capture is an empty base and keeps nothing) -- through a deduction guide. The lambdas capture by reference, are generic, and one base is
// an ordinary class; the object is called through a const reference.
#include <cstdio>
template <class... Ts> struct overloaded : Ts... { using Ts::operator()...; };
template <class... Ts> overloaded(Ts...) -> overloaded<Ts...>;
struct Probe { int n; int operator()(long x) const { return (int) x + n; } };
int main() {
  int base = 7;
  int k = 5;
  overloaded o{ [](int x) { return x + 1; }, [&](double d) { return (int) (d * 2) + base; }, [](auto *p) { return (int) sizeof(*p); }, Probe{100} };
  const auto &co = o;
  int i = 3; double dd = 2.5; char c = 'x'; long l = 5;
  std::printf("%d %d %d\n", co(i), co(dd), co(&c));
  std::printf("%d %d\n", co(&l), co(l));
  overloaded o2{ [&](int x) { return x + k; }, [&](double d) { return (int) (d * 2) + base; } };
  std::printf("%d %d\n", o2(3), o2(2.5));
  overloaded o3{ [](int x) { return x + 1; }, [](double d) { return (int) (d * 2); } };
  std::printf("%d %d\n", o3(1), o3(2.5));
  return 0;
}
