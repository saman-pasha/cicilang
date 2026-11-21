// A reference bound to a conditional's value (1.6.13): its condition moves p, and the free after it is a use after the
// move. Through 1.6.12 the program freed p twice
#include <cstdio>
#include <cstdlib>
int b = 2;
int consume(own int *p) { free(p); return 1; }
static own int *make() { own int *p = (int *)malloc(sizeof *p); if (!p) abort(); *p = 1; return p; }
int main() { own int *p = make(); const int &r = consume(move(p)) ? b : b; free(p); std::printf("%d\n", r); return 0; }
