// libc++'s C++23 facilities by their feature-test macros (0.206): byteswap (llvm.bswap), to_underlying,
// is_scoped_enum, unreachable, forward_like, invoke_r, string's contains, resize_and_overwrite (a callee written
// std::move(op)), the adaptors' iterator-pair constructors, allocate_at_least, ios_base::noreplace, constexpr bitset,
// to_chars and from_chars, unique_ptr and type_info, and string_view's substr.
#include <bit>
#include <bitset>
#include <charconv>
#include <cstdint>
#include <cstdio>
#include <deque>
#include <functional>
#include <ios>
#include <memory>
#include <queue>
#include <stack>
#include <string>
#include <string_view>
#include <type_traits>
#include <typeinfo>
#include <utility>
#include <vector>

enum class Color : unsigned char { red = 3, green = 7 };
enum Plain { pa = 1 };

constexpr int bits() {
  std::bitset<8> b("10110010");
  b.flip(0);
  return int(b.count()) * 1000 + int(b.to_ulong());
}
constexpr int chars() {
  char buf[8] = {};
  auto r = std::to_chars(buf, buf + 8, 1234);
  int v = 0;
  std::from_chars(buf, r.ptr, v);
  return v + int(r.ptr - buf);
}
constexpr int uptr() {
  auto p = std::make_unique<int>(41);
  ++*p;
  return *p;
}
constexpr bool tid() { return typeid(int) == typeid(int) && typeid(int) != typeid(long); }

int main() {
  std::printf("byteswap %08x %04x\n", std::byteswap(0x11223344u), (unsigned) std::byteswap(std::uint16_t(0xabcd)));
  std::printf("to_underlying %d %d %d\n", std::to_underlying(Color::green), (int) std::is_same_v<decltype(std::to_underlying(Color::red)), unsigned char>,
              std::to_underlying(pa));
  std::printf("scoped %d %d\n", (int) std::is_scoped_enum_v<Color>, (int) std::is_scoped_enum_v<Plain>);
  int x = 3;
  if (x > 5) std::unreachable();
  std::printf("unreachable %d\n", x);
  const int ci = 4;
  auto &&fl = std::forward_like<const int &>(x);
  std::printf("forward_like %d %d\n", (int) std::is_same_v<decltype(fl), const int &>, ci + fl);
  long r = std::invoke_r<long>([](int a) { return a * 2; }, 21);
  std::invoke_r<void>([](int a) { return a; }, 1);
  std::printf("invoke_r %ld\n", r);
  std::string s = "hello world";
  std::printf("contains %d %d %d\n", (int) s.contains("lo w"), (int) s.contains('z'), (int) std::string_view("abc").contains("bc"));
  std::string t;
  t.resize_and_overwrite(5, [](char *p, std::size_t n) { for (std::size_t i = 0; i < n; ++i) p[i] = char('a' + i); return n - 1; });
  std::printf("resize_and_overwrite %s %zu\n", t.c_str(), t.size());
  std::vector<int> src{1, 2, 3, 4};
  std::stack<int> st(src.begin(), src.end());
  std::queue<int> qu(src.begin(), src.end());
  std::printf("adaptors %d %d %zu\n", st.top(), qu.front(), qu.size());
  std::allocator<int> al;
  auto res = al.allocate_at_least(5);
  std::printf("allocate_at_least %d\n", (int) (res.count >= 5));
  al.deallocate(res.ptr, res.count);
  std::printf("noreplace %d\n", (int) (std::ios_base::noreplace != 0));
  constexpr int bb = bits(), cc = chars(), uu = uptr();
  constexpr bool tt = tid();
  std::printf("constexpr %d %d %d %d\n", bb, cc, uu, (int) tt);
  std::string_view sv = "abcdef";
  std::printf("substr %s\n", std::string(sv.substr(2, 3)).c_str());
  std::printf("string_view range %zu\n", std::string_view(src.size() > 0 ? std::string_view("xyz") : std::string_view()).size());
}
