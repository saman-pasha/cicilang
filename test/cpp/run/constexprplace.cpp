#include <cstdio>
#include <memory>
constexpr int place() { struct V { int a; } v{1}; V *p = std::construct_at(&v, V{7}); return p->a; }
constexpr int voidcast() { int x = 9; void *p = &x; return *static_cast<int *>(p); }
int main() { static_assert(place() == 7 && voidcast() == 9); std::printf("%d %d\n", place(), voidcast()); }
