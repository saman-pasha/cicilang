// A DELETED OVERLOAD BESIDE THE ONE THE CALL CHOOSES IS NO REFUSAL (0.257): a deleted copy beside a move, a deleted member
// beside the overload chosen, a deleted free function with its reason beside the one called, unique_ptr moved through a
// vector, a return and a by-value parameter, strings and vectors copied, a class whose copy is deleted made from a
// prvalue (C++17 elides the copy), and a defaulted copy assignment -- each builds and runs as clang++ has it.
#include <cstdio>
#include <memory>
#include <string>
#include <vector>
struct S { int v = 42; S() {} S(const S &) = delete; S(S &&o) : v(o.v) {} void f(int) = delete; int f(long) { return v; } };
void g(int) = delete("call g(long)");
int g(long n) { return (int)n; }
struct M { int v = 7; M() {} M(const M &) = delete; M(M &&o) : v(o.v) {} };
M make() { return M(); }
M pass(M m) { return m; }
std::unique_ptr<int> mk(int n) { return std::make_unique<int>(n); }
int take(std::unique_ptr<int> p) { return *p; }
struct H { std::unique_ptr<int> p; std::string s; };
struct R { int x, y; };
struct T { R r; int k; T &operator=(const T &) = default; };
int main() {
  S a; S b = static_cast<S &&>(a);
  M m1 = make(); M m2 = static_cast<M &&>(m1); M m3 = pass(M());
  std::vector<std::unique_ptr<int>> v; v.push_back(mk(3));
  auto q = mk(4);
  std::string s1 = "xyz"; std::string s2 = s1;
  std::vector<int> va{1, 2}; std::vector<int> vb = va;
  H h{mk(5), "ab"}; H h2 = std::move(h);
  R r1{1, 2}, r2{3, 4}; r1 = r2;
  T t1{{1, 2}, 3}, t2{{5, 6}, 7}; t1 = t2;
  std::printf("%d %ld %d %d %d %zu %zu %d %zu %d %d\n", b.f(1L), (long)g(9L), m2.v + m3.v, *v[0], take(std::move(q)), s2.size(), vb.size(), *h2.p, h2.s.size(), r1.x, t1.k);
  return 0;
}
