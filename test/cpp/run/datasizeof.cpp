// clang's `__datasizeof(T)': a POD's whole size, else the byte where its last member ends; libc++ 18 copies a
// trivially copyable range by it, std::copy and a string's copy through `__constexpr_memmove' (0.112)
#include <algorithm>
#include <cstdio>
#include <string>
struct P { int a; char b; };
struct Q { Q() : a(1), b(2) {} int a; char b; };
struct D : P { char c; };
int main() {
  std::printf("%d %d %d %d %d\n", (int) __datasizeof(char), (int) __datasizeof(int), (int) __datasizeof(P), (int) __datasizeof(Q), (int) __datasizeof(D));
  P a[3] = {{1, 'a'}, {2, 'b'}, {3, 'c'}};
  P b[3] = {};
  std::copy(a, a + 3, b);
  std::printf("%d%c %d%c %d%c\n", b[0].a, b[0].b, b[1].a, b[1].b, b[2].a, b[2].b);
  std::string s = "hello", t;
  t = s;
  t += " world";
  std::printf("%s\n", t.c_str());
  return 0;
}
