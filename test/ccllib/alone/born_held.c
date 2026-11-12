// AN OBJECT THAT HOLDS AN INSTANCE'S IS BORN ZERO (0.297): a struct with a vector member (the Ambitious session's
// finding 20: `holder h; push_back(h.items, k);' wrote through its garbage), a struct of such in an array member of
// another, a struct with a string member, an array of such structs and a for's declaration, declared with no
// initializer, are each empty at their first use over storage written with garbage first; a designated initializer
// and a memset of zero leave the same, as C has them
#include <stdio.h>
#include <string.h>
#include <vector.pl>
#include <string.pl>
typedef struct holder { vector<int> items; int n; } holder;
typedef struct inner { int k; vector<int> v; } inner;
typedef struct outer { double d; inner in[2]; } outer;
typedef struct named { string name; int id; } named;
static void scribble(void) { volatile unsigned char junk[1024]; for (int i = 0; i < 1024; i++) junk[i] = (unsigned char)(0xA5 + i); (void)junk[0]; }
static int one(int k) { holder h; push_back(h.items, k); int n = (int)len(h.items) + h.n; vector_int_drop(&h.items); return n; }
static int nested(void) {
    outer o;
    push_back(o.in[1].v, 4);
    int n = (int)(len(o.in[0].v) + len(o.in[1].v) * 10) + o.in[0].k + (int)o.d;
    vector_int_drop(&o.in[0].v);
    vector_int_drop(&o.in[1].v);
    return n;
}
static int text(void) { named x; append(x.name, "abc"); int n = (int)size(x.name) + x.id; basic_string_char_drop(&x.name); return n; }
static int many(void) {
    holder hs[2];
    push_back(hs[1].items, 4);
    int n = (int)(len(hs[0].items) + len(hs[1].items) * 10);
    vector_int_drop(&hs[0].items);
    vector_int_drop(&hs[1].items);
    return n;
}
static int loop(void) { int t = 0; for (holder h; t < 1; t++) { push_back(h.items, 4); t += (int)len(h.items); vector_int_drop(&h.items); } return t; }
static int designated(void) { holder h = { .n = 3 }; push_back(h.items, 4); int n = (int)len(h.items) * 10 + h.n; vector_int_drop(&h.items); return n; }
static int filled(void) { holder h; memset(&h, 0, sizeof h); push_back(h.items, 1); int n = (int)len(h.items); vector_int_drop(&h.items); return n; }
int main(void) {
    int r[7];
    scribble(); r[0] = one(1);
    scribble(); r[1] = nested();
    scribble(); r[2] = text();
    scribble(); r[3] = many();
    scribble(); r[4] = loop();
    scribble(); r[5] = designated();
    scribble(); r[6] = filled();
    printf("%d %d %d %d %d %d %d\n", r[0], r[1], r[2], r[3], r[4], r[5], r[6]);
    return 0;
}
