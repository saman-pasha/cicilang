/* own parameters that their callee stores (1.6.5): into an own array, into a global through a chain of two calls and
   by a written move, and into a struct that the call returns. Built as C and as C++ (test/cpp.sh), where through
   1.6.4 C++ refused the first two forms, `a borrow stored where it cannot be followed', and took the written move */
#include <stdio.h>
#include <stdlib.h>
typedef struct blk { int v; } blk;
typedef struct holder { own blk *p; } holder;
own blk *slot[4];
static own blk *keep;
size_t put(own blk *b) { free(slot[0]); slot[0] = b; return 1; }
void keep_it(own blk *b) { free(keep); keep = b; }
void keep_it2(own blk *b) { keep_it(b); }
holder wrap(own blk *b) { holder h; h.p = b; return h; }
static own blk *make(int v) { own blk *b = malloc(sizeof *b); if (!b) abort(); b->v = v; return b; }
int main(void) {
    own blk *a = make(3);
    size_t n = put(a);
    own blk *c = make(5);
    keep_it2(c);
    int first = keep->v;
    own blk *e = make(8);
    keep_it(move(e));
    own blk *d = make(6);
    holder h = wrap(d);
    printf("%d %d %d %d %d\n", (int)n, slot[0]->v, first, keep->v, h.p->v);
    free(slot[0]); slot[0] = 0;
    free(keep); keep = 0;
    free(h.p); h.p = 0;
    return 0;
}
