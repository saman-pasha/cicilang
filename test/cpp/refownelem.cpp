// An own array's element assigned where C++ takes the assignment for a place (1.6.13): the old element is freed in a
// block of its own, whose place no reference takes, so the form is refused by name
#include <cstdio>
#include <cstdlib>
typedef struct thing { int v; } thing;
static own thing *slot[2];
static own thing *make(int v) noexcept { own thing *t = (thing *)malloc(sizeof *t); if (!t) abort(); t->v = v; return t; }
int main() { thing *&r = (slot[0] = make(4)); std::printf("%d\n", r->v); free(slot[0]); slot[0] = nullptr; return 0; }
