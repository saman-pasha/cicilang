// GCC's `constructor' and `destructor' in C++ (1.6.8): the attribute's constructor before the unit's dynamic
// initialization, of the same priority; its destructor after main's return. (A global object's destructor and an
// attribute's destructor run in clang's two orders: after the object's on Linux, from .fini_array, and before it on a
// Mac, where clang registers it with __cxa_atexit after the object's own registration -- so no object here has one.)
#include <cstdio>
struct G { int n; G() : n(7) { std::printf("G() %d\n", n); } };
G g;
__attribute__((constructor)) static void init() { std::printf("init %d\n", g.n); }
__attribute__((destructor)) static void fini() { std::printf("fini %d\n", g.n); }
int main() { std::printf("main %d\n", g.n); return 0; }
