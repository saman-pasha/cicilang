// STATIC STORAGE FREED THROUGH A NAMESPACE'S FUNCTION (1.6.16): a function whose every return is static storage is
// known in a namespace too (0.294, statret_free.c), and its result freed is refused
#include <cstdlib>
namespace tbl {
int table[4];
int *row(int i) { return table + i; }
}
int main() { int *p = tbl::row(1); std::free(p); return 0; }
