// A STRING LITERAL IS AN LVALUE OF `const char[N]' IN C++ ([lex.string]/10, [expr.prim.literal]/1): an overload taking
// `const char *' is the better one, a template deduces the pointer it decays to by value and the array by reference;
// an array's bound is part of its type, and its cv-qualifiers are its element's ([basic.type.qualifier]/3)
#include <cstdio>
#include <string>
#include <type_traits>
#include <utility>
#include <vector>
int f(char *) { return 1; }
int f(const char *) { return 2; }
int g(char *) { return 3; }
template <class T> int byval(T) { return std::is_same_v<T, const char *> ? 10 : std::is_same_v<T, char *> ? 11 : 12; }
template <class T> int byref(T &) { return std::is_same_v<T, const char[4]> ? 20 : 21; }
template <class T> int fwd(T &&) { return std::is_same_v<T, const char (&)[4]> ? 30 : 31; }
template <class T, unsigned long N> int arr(T (&)[N]) { return (int) N * 100 + (std::is_same_v<T, const char> ? 1 : 2); }
template <class T> int sz(T &) { return (int) sizeof(T); }
template <class... Ts> int count(Ts &&...xs) { return (int) (sizeof(xs) + ... + 0); }
int len(const char (&a)[6]) { return (int) sizeof a; }
struct F { int x; };
template <class... A> int pick(F *, const char *, A &&...) { return 1; }
template <class... A> int pick(const char *, A &&...) { return 2; }
int take(const char *s) { return (int) s[1]; }
template <class... A> int via(A &&...a) { return take(static_cast<A &&>(a)...); }
int main() {
  auto p = "abc";
  decltype("abc") r = "xyz";
  std::printf("%d %d %d\n", f("abc"), g((char *) "abc"), f(p));
  std::printf("%d %d %d %d\n", byval("abc"), byref("abc"), fwd("abc"), arr("hello"));
  std::printf("%d %d %d %c\n", (int) std::is_same_v<decltype(p), const char *>, (int) std::is_same_v<decltype(r), const char (&)[4]>, len("hello"), r[1]);
  std::printf("%d %d\n", (int) std::is_same_v<decltype("ab"), const char (&)[3]>, (int) sizeof("abcd"));
  int a[3] = {1, 2, 3}, b[5] = {};
  std::printf("%d %d %d %d %d\n", sz(a), sz(b), sz("ab"), sz("abcd"), count("a", "bcd", 'x'));
  std::printf("%d %d %d %d\n", (int) std::is_const_v<int *const>, (int) std::is_const_v<const char[4]>, (int) std::is_const_v<const int *>,
              (int) std::is_same_v<std::remove_const_t<const char[4]>, char[4]>);
  std::printf("%d %d %d %d\n", pick("x", "y"), pick("x"), take(static_cast<const char (&)[4]>("abc")), via("xyz"));
  std::vector<std::string> v;
  v.emplace_back("hello");
  v.push_back("world");
  std::pair<std::string, int> pr = std::make_pair("key", 7);
  std::string s = std::string("ab") + "cd";
  std::printf("%s %s %s %d %s %d\n", v[0].c_str(), v[1].c_str(), pr.first.c_str(), pr.second, s.c_str(), (int) s.size());
  return 0;
}
