// Partial ordering: an overload over a class template-id is more specialized than the generic one.
#include <cstdio>
struct ios_b { int x; };
struct os_t : ios_b { };
template <class C> struct tr { };
template <class C, class T> struct obi { obi(os_t &) { } bool failed() const { return false; } };
template <class C, class O> O pad(O s, const C *, const C *, const C *, ios_b &, C) { std::puts("generic"); return s; }
template <class C, class T> obi<C, T> pad(obi<C, T> s, const C *, const C *, const C *, ios_b &, C) { std::puts("special"); return s; }
int main() {
  os_t o; const char *s = "ab";
  pad(obi<char, tr<char>>(o), s, s, s + 2, o, ' ');
  return 0;
}
