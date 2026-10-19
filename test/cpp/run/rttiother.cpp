// the type information of every other type (0.180): an enum and a scoped one, a pointer to a pointer and to an enum, a
// pointer to a data member and to a member function, an array, a function, std::nullptr_t, a pointer to a volatile
// builtin, the builtins that libc++abi does not export (_Float16, _BitInt), a vector type, and a pointer to each; each
// compared, thrown and caught. clang++ declares _Float16's and its pointer's external, which libc++abi does not export:
// the expect is clang++'s output with the two supplied as clang lays out a _BitInt's
#include <cstddef>
#include <cstdio>
#include <typeinfo>
enum Color { Red, Green };
enum class Mode : unsigned char { Fast, Slow };
struct A { int a; int f(int) { return a; } };
template <class T> struct Box { T v; };
typedef int v4si __attribute__((vector_size(16)));
typedef float f2 __attribute__((ext_vector_type(2)));
int g(double) { return 1; }
int main() {
  Color c = Green; Mode m = Mode::Slow; int x = 3; int *px = &x; int **ppx = &px; int A::*pm = &A::a;
  int (A::*pf)(int) = &A::f; int arr[3] = {1, 2, 3}; const char *const *pcs = nullptr; Color *pc = &c;
  std::printf("%s %s %s %s\n", typeid(c).name(), typeid(m).name(), typeid(ppx).name(), typeid(pcs).name());
  std::printf("%s %s %s %s\n", typeid(pm).name(), typeid(pf).name(), typeid(arr).name(), typeid(g).name());
  std::printf("%s %s %s\n", typeid(std::nullptr_t).name(), typeid(pc).name(), typeid(Box<int>).name());
  std::printf("%d %d %d\n", typeid(c) == typeid(Color), typeid(int *) == typeid(px), typeid(Mode) == typeid(Color));
  try { throw Green; } catch (Color e) { std::printf("caught %d\n", (int) e); }
  try { throw &c; } catch (Color *p) { std::printf("caught ptr %d\n", (int) *p); }
  volatile int vi = 4; volatile int *pvi = &vi; const volatile char *pcv = nullptr;
  std::printf("%s %s %s %s\n", typeid(std::nullptr_t).name(), typeid(nullptr).name(), typeid(pvi).name(),
              typeid(pcv).name());
  std::printf("%d %d\n", typeid(std::nullptr_t) == typeid(nullptr), typeid(pvi) == typeid(int *));
  try { throw nullptr; } catch (int *p) { std::printf("caught as a pointer %d\n", p == nullptr); }
  try { throw nullptr; } catch (std::nullptr_t n) { std::printf("caught as nullptr_t %d\n", n == nullptr); }
  try { throw pvi; } catch (volatile int *p) { std::printf("caught a volatile pointer %d\n", *p); }
  _Float16 h = 1.5; _BitInt(37) b = 5; unsigned _BitInt(7) u = 3; char8_t c8 = u8'a';
  std::printf("%s %s %s %s\n", typeid(h).name(), typeid(b).name(), typeid(u).name(), typeid(c8).name());
  std::printf("%s %s %s\n", typeid(&h).name(), typeid(&b).name(), typeid(const _BitInt(37) *).name());
  std::printf("%d %d\n", typeid(h) == typeid(_Float16), typeid(b) == typeid(_BitInt(38)));
  try { throw b; } catch (_BitInt(37) e) { std::printf("caught %d\n", (int) e); }
  try { throw &h; } catch (_Float16 *p) { std::printf("caught a half pointer %d\n", (int) *p); }
  v4si va = {1, 2, 3, 4}; f2 vf = {1.0f, 2.0f};
  std::printf("%s %s %s\n", typeid(va).name(), typeid(vf).name(), typeid(&va).name());
  std::printf("%d %d\n", typeid(va) == typeid(v4si), typeid(vf) == typeid(va));
  try { throw va; } catch (v4si e) { std::printf("caught a vector %d\n", e[2]); }
  return 0;
}
