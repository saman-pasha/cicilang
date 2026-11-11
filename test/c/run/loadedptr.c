/* A POINTER READ OUT OF A SLOT IS NO NEW MEMORY, AND A NULL TEST REFINES A PLAIN POINTER THAT HOLDS NEW MEMORY (0.290).
   A plain local given `names[i]', `g.name', a global pointer's value or `r->name' was a loose pointer, which its
   function must free, return or store: each line of rows() was `plain pointer not consumed'. A field, an element, a
   global and `*p' given such a value were `no owner behind': each store of stores(), and a record that holds a
   pointer, read out of a table by value. And `FILE *f = fopen(...); if (f == NULL) return -1; fclose(f);', the
   README's lines, was refused at the return: on the path where the pointer is null it holds nothing. This file is C
   and C++: cicilang++ builds it too */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static const char *const names[] = { "a", "bb", "ccc" };
static const char *tab[2] = { "t0", "t1" };
struct rec { const char *name; int k; };
static struct rec g = { "gg", 1 };
static struct rec recs[2] = { { "r0", 0 }, { "r1", 1 } };
static const char *gp = "gp";
static int rows(int i) {
    const char *a = names[i % 3];
    const char *b = tab[i % 2];
    const char *c = g.name;
    const char *d = recs[i % 2].name;
    const char *e = gp;
    const struct rec *r = &recs[i % 2];
    const char *f = r->name;
    const char *h;
    h = names[(i + 1) % 3];
    const char *j = *(names + 2);
    const char *const *pp = names;
    const char *k = pp[1];
    const char *m = i ? names[0] : "lit";
    printf("%s %s %s %s %s %s %s %s %s %s\n", a, b, c, d, e, f, h, j, k, m);
    return (int)(strlen(a) + strlen(h));
}
struct tok { const char *text; int n; };
static struct tok toks[2] = { { "x", 1 }, { "yy", 2 } };
static struct tok gt;
static const char *g2;
static void put_rec(struct tok *out, int i) { *out = toks[i % 2]; }
static void put_name(struct tok *t, int i) { t->text = names[i % 3]; t->n = i; }
static int stores(int i) {
    struct tok t = { 0, 0 };
    t.text = names[i % 3];
    struct tok u = { tab[i % 2], 7 };
    struct tok v = toks[i % 2];
    struct tok w;
    w = toks[(i + 1) % 2];
    struct tok a[2];
    a[0] = toks[0];
    a[1].text = i ? names[1] : names[2];
    a[1].n = 0;
    const char *lst[2];
    lst[0] = names[0];
    lst[1] = g.name;
    g2 = names[(i + 2) % 3];
    gt = toks[i % 2];
    struct tok f;
    put_rec(&f, i + 1);
    struct tok n;
    put_name(&n, i + 1);
    struct tok *h = (struct tok *)malloc(sizeof *h);
    if (!h) return -1;
    *h = toks[i % 2];
    h->text = recs[i % 2].name;
    own struct tok *o = (struct tok *)malloc(sizeof *o);
    if (!o) { free(h); return -1; }
    o->text = gp;
    o->n = 2;
    printf("%s %s %s %s %s %s %s %s %s %s %s %s %s %s\n", t.text, u.text, v.text, w.text, a[0].text, a[1].text, lst[0],
           lst[1], g2, gt.text, f.text, n.text, h->text, o->text);
    int k = h->n + u.n + n.n + o->n;
    free(h);
    free(o);
    return k;
}
static const char *pick(int i) {
    const char *s = names[i % 3];
    return s;
}
static int opened(const char *path) {
    FILE *f = fopen(path, "r");
    if (f == NULL) return -1;
    fclose(f);
    return 0;
}
static int maybe(const char *path) {
    FILE *f = fopen(path, "r");
    int had = 0;
    if (f) { had = 1; fclose(f); }
    return had;
}
static int sized(size_t n) {
    char *p = (char *)malloc(n);
    if (!p) return -1;
    memset(p, 'x', n);
    int k = p[n - 1] == 'x';
    free(p);
    return k;
}
int main(void) {
    printf("%d %d\n", rows(0), rows(1));
    printf("%d %d\n", stores(0), stores(1));
    printf("%s %s\n", pick(1), pick(5));
    printf("%d %d\n", opened("/dev/null"), opened("/no/such/file/here"));
    printf("%d %d\n", maybe("/dev/null"), maybe("/no/such/file/here"));
    printf("%d\n", sized(16));
    return 0;
}
