/* OWN ARRAYS OF STATIC STORAGE (0.307; the Ambitious session's finding 38): an own array at file scope, an own array
   member of a static struct and a static local own array, each an own array as a local one is -- an element taken by
   move(), which empties its slot, a moved result, a store that frees the old element, an element handed to a consumer,
   a plain read, a borrow kept over a call that stores into no such array and over a C library call, a borrow taken
   after a call that stores, an extern declaration in a block, a parameter that hides the array's name, an initializer,
   a static local array over two calls and a result tied to the array. Valgrind finds no error and nothing lost */
#include <stdio.h>
#include <stdlib.h>
typedef struct thing { int v; } thing;
typedef struct table { int n; own thing *a[2]; } table;
static own thing *slot[2];
static own thing *more[2] = {0};
static table g;
static own thing *make(int v) {
    own thing *t = malloc(sizeof *t);
    if (t) t->v = v;
    return t;
}
static own thing *take(void) { return move(slot[1]); }
static void put(int v) { slot[1] = make(v); }
static int count(void) { int n = 0; for (int i = 0; i < 2; i++) if (slot[i]) n++; return n; }
static void eat(own thing *t) { if (t) printf("ate %d\n", t->v); free(t); }
static int value(own thing *slot) { int v = slot ? slot->v : 0; free(slot); return v; }
static thing *peek(void) tie slot { return slot[0]; }
static void keep(int v) {
    static own thing *s[1];
    s[0] = make(v);
    if (s[0]) printf("kept %d\n", s[0]->v);
}
int main(void) {
    slot[0] = make(1);
    own thing *out = move(slot[0]);
    slot[0] = make(2);
    printf("%d %d\n", out ? out->v : 0, slot[0] ? slot[0]->v : 0);
    free(out);
    put(6);
    put(7);
    own thing *t = take();
    printf("taken %d, %d left\n", t ? t->v : 0, count());
    free(t);
    eat(move(slot[0]));
    slot[0] = make(3);
    thing *b = slot[0];
    int n = count();
    printf("read %d over %d\n", b ? b->v : 0, n);
    printf("still %d\n", b ? b->v : 0);
    put(8);
    thing *c = slot[1];
    printf("after the call %d\n", c ? c->v : 0);
    thing *p = peek();
    printf("peeked %d\n", p ? p->v : 0);
    printf("value %d\n", value(move(slot[1])));
    {
        extern own thing *more[2];
        more[1] = make(4);
        own thing *m = move(more[1]);
        printf("extern %d\n", m ? m->v : 0);
        free(m);
    }
    g.a[1] = make(9);
    g.n = 1;
    own thing *e = move(g.a[1]);
    printf("member %d %d\n", e ? e->v : 0, g.n);
    free(e);
    keep(10);
    keep(11);
    free(move(slot[0]));
    return 0;
}
