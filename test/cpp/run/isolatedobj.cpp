// a member template emitted while a CONST object's call is chosen is walked as its own body: `*r = f[i]' inside it
// takes Out's non-const operator=, as libc++ 18's ranges::copy (a const customization point object) reaches
// `*__result = *__first' in __copy_loop
#include <cstdio>
struct Out {
  int *p;
  Out &operator=(int v) { *p += v; return *this; }
  Out &operator*() { return *this; }
};
struct Copy {
  template <class O> O operator()(const int *f, int n, O r) const { for (int i = 0; i < n; ++i) *r = f[i]; return r; }
};
const Copy copy{};
int main() {
  int sum = 0;
  int a[3] = {1, 2, 3};
  Out o{&sum};
  copy(a, 3, o);
  std::printf("%d\n", sum);
  return 0;
}
