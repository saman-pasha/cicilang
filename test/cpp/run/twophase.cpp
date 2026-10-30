// TWO-PHASE LOOKUP ([temp.dep.candidate], [basic.lookup.argdep]): an unqualified call in a library template finds the
// program's global functions only by argument-dependent lookup -- libc++'s iter_swap calls `swap(*a, *b)', and the
// program's global `swap(int &, int &)' is no candidate for two ints, while its `swap(G &, G &)' is for its own class G
#include <algorithm>
#include <cstdio>
#include <utility>

static int mine = 0;
void swap(int &a, int &b) { ++mine; int t = a; a = b; b = t; }   // never called by the library: an int has no namespace
struct G { int v; };
void swap(G &a, G &b) { mine += 10; std::swap(a.v, b.v); }        // found by ADL: G is the global namespace's

int main() {
  int x = 1, y = 2;
  std::iter_swap(&x, &y);
  G g{3}, h{4};
  std::iter_swap(&g, &h);
  int a[3] = {5, 6, 7};
  std::reverse(a, a + 3);
  int lib = mine;
  swap(x, y);   // the program's own call finds it
  std::printf("%d %d %d %d %d %d %d %d\n", x, y, g.v, h.v, a[0], a[2], lib, mine);
  return 0;
}
