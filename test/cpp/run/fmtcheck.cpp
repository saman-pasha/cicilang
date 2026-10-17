// THE FORMAT STRING CHECKED AT COMPILE TIME (0.164): basic_format_string's consteval constructor runs in the evaluator
// for each of these -- positional and automatic arguments, fill and alignment, signs, bases, widths and precisions
// from arguments, the char, bool, string, pointer and floating formatters, escapes, a wide string and a user formatter
// with a parse of its own -- and each builds, as clang++ builds it; test/cpp/fmtindex.cpp and fmttype.cpp are refused
#include <format>
#include <string>
#include <string_view>
#include <cstdio>
struct P { int x, y; };
template <> struct std::formatter<P> {
  bool brief = false;
  constexpr auto parse(std::format_parse_context &ctx) {
    auto it = ctx.begin();
    if (it != ctx.end() && *it == 'b') { brief = true; ++it; }
    return it;
  }
  template <class Ctx> auto format(const P &p, Ctx &ctx) const {
    return brief ? std::format_to(ctx.out(), "{}", p.x) : std::format_to(ctx.out(), "({}, {})", p.x, p.y);
  }
};
int main() {
  int i = 42; unsigned u = 7u; long long ll = -5; double d = 3.25; float f = 1.5f; char c = 'x'; bool b = true;
  const char *cs = "cstr"; std::string s = "str"; std::string_view sv = "sv"; void *p = nullptr;
  std::string out;
  out += std::format("{}|", i);
  out += std::format("{:5}|{:<5}|{:^5}|{:>5}|", i, i, i, i);
  out += std::format("{:*^9}|{:+}|{: }|{:#x}|{:#o}|{:#b}|{:08X}|", i, i, i, i, i, i, i);
  out += std::format("{0} {1} {0}|", i, u);
  out += std::format("{} {} {}|", ll, d, f);
  out += std::format("{:.2f} {:e} {:g} {:a} {:10.3f}|", d, d, d, d, d);
  out += std::format("{} {:?} {:d}|", c, c, c);
  out += std::format("{} {:s} {:d}|", b, b, b);
  out += std::format("{} {} {}|", cs, s, sv);
  out += std::format("{:>8} {:.2} {:?}|", s, sv, s);
  out += std::format("{}|", p);
  out += std::format("{{}} {{{}}}|", i);
  out += std::format("{:{}}|{:.{}f}|{:{}.{}f}|", i, 6, d, 1, d, 8, 2);
  out += std::format("{0:{1}}|", i, 4);
  out += std::format("{} {:b}|", P{1, 2}, P{3, 4});
  out += std::format("no args|");
  std::wstring w = std::format(L"{} {:>4}|", 7, L"ab");
  out += std::to_string(w.size());
  std::puts(out.c_str());
  return 0;
}
