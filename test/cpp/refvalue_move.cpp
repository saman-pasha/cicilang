// A reference bound to a value (1.6.13): the temporary C++ makes has no place to borrow, and the initializer is walked for
// what it does -- here it moves p, so the free after it is a use after the move. Through 1.6.12 the walk was left out with
// the borrow, and the program freed p twice
#include <cstdio>
#include <cstdlib>
int consume(own int *p) { free(p); return 1; }
static own int *make() { own int *p = (int *)malloc(sizeof *p); if (!p) abort(); *p = 1; return p; }
int main() { own int *p = make(); const int &r = consume(move(p)); free(p); std::printf("%d\n", r); return 0; }
