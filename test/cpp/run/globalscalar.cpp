// a file-scope SCALAR initialized by an expression of the run time (0.117, [basic.start.dynamic]): a call, a read of another
// global, a conditional over calls, a braced initializer, a static data member defined out of its class, the address of an
// array element, a `const' object. They are initialized before `main' in the order of their declarations, as clang++ does.
#include <cstdio>
static int f(int x) { std::printf("f(%d)\n", x); return x * 3; }
int g = f(2) * 2;
static int h = g + 4;
const int k = f(5);
double d = f(1) / 2.0;
const char *name = f(0) ? "yes" : "no";
bool flag = f(1) > 2;
struct A {
  static int v;
  static int compute() { std::printf("compute\n"); return 21; }
};
int A::v = A::compute() * 2;
class B { static int make() { return 5; } static int w; friend int main(); };
int B::w = B::make() + 1;
enum Color { Red, Green };
Color c = f(0) == 0 ? Green : Red;
int br{f(3)};
int br2 = {f(4)};
int arr[4] = {1, 2, 3, 4};
int *ptr_in = &arr[2];
int *same = &g;
namespace N { int z = f(7); long q = z + 1L; }
int main() {
  std::printf("%d %d %d %.2f %s %d %d %d\n", g, h, k, d, name, flag, A::v, (int)c);
  std::printf("%d %d %d %d %d %d %d %ld\n", br, br2, *ptr_in, *same, (int)(same == &g), B::w, N::z, N::q);
  return 0;
}
