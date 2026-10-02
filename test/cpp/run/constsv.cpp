// A constant object of a class WITH constructors, braced-initialized from a string literal: built by its
// constructor at compile time (never as an aggregate), the literal's length counted by the evaluator's strlen,
// and the pointer into the literal kept, at its offset, as the global's constant; a static member function
// called in a constexpr constructor takes the null `this'.
#include <cstdio>
#include <string_view>

template <class C> struct Words {
  static constexpr std::basic_string_view<C> yes{"true"};
  static constexpr std::basic_string_view<C> no{"false"};
};

constexpr std::string_view hello{"hello"};
constexpr std::string_view tail{"hello, world" + 7};

struct Name {
  int n;
  static constexpr int len(const char *s) { int k = 0; while (s[k]) ++k; return k; }
  constexpr Name(const char *s) : n(len(s)) {}
};
constexpr Name ann{"anna"};

int main() {
  std::printf("%d %d %s %s\n", (int) Words<char>::yes.size(), (int) Words<char>::no.size(), Words<char>::yes.data(), Words<char>::no.data());
  std::printf("%d %s\n", (int) hello.size(), hello.data());
  std::printf("%d %s\n", (int) tail.size(), tail.data());
  std::printf("%d\n", ann.n);
  std::printf("%d\n", (int) (hello == "hello"));
  return 0;
}
