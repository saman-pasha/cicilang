// C++20's constant evaluation: virtual calls, dynamic_cast, try blocks, union member changes, transient allocation
// (std::vector and std::string in a constant expression), std::is_constant_evaluated
#include <cstdio>
#include <vector>
#include <string>
#include <type_traits>
struct Base { constexpr virtual int f() const { return 1; } constexpr virtual ~Base() = default; };
struct Der : Base { constexpr int f() const override { return 2; } };
constexpr int vcall() { Der d; const Base &b = d; return b.f(); }
constexpr int dyn() { Der d; Base *b = &d; return dynamic_cast<Der *>(b) ? 5 : 0; }
constexpr int tryblk(int x) { try { return x * 2; } catch (...) { return -1; } }
union UU { int i; float f; };
constexpr int uswap() { UU u{.i = 3}; u.f = 1.5f; u.i = 4; return u.i; }
constexpr int sumv() { std::vector<int> v{1, 2, 3}; v.push_back(4); int s = 0; for (int x : v) s += x; return s; }
constexpr std::size_t slen() { std::string s = "hello"; s += " world"; return s.size(); }
constexpr int heap() { int *p = new int(6); int r = *p; delete p; return r; }
int main() {
    static_assert(vcall() == 2 && dyn() == 5 && tryblk(3) == 6 && uswap() == 4);
    static_assert(heap() == 6);
    static_assert(sumv() == 10);
    static_assert(slen() == 11);
    constexpr bool ce = std::is_constant_evaluated();
    std::printf("%d %d %d %d %d %zu %d %d\n", vcall(), dyn(), tryblk(3), uswap(), sumv(), slen(), heap(), (int) ce);
}
