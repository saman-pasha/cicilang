#include <cstdio>
#define HAS_X
int main() {
#ifdef NOPE
std::puts("no");
#elifdef HAS_X
std::puts("elifdef");
#endif
{ int k = 1; if (k) goto end; std::puts("skipped"); end: } }
