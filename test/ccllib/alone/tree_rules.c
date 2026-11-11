/* THE RULES OF THE TREE of <set.pl> and <map.pl> (0.281), checked from outside over a walk of chance: each node but
   the root holds 7 to 15 entries, an inner node has one child more than its entries, the leaves stand at one depth,
   the entries are in their order -- a multimap's equal keys in the order of their insert --, the count of the entries
   is the tree's, and each node of the arena is in the tree or in the chain of the erased ones. A set and a multimap
   grow, shrink to nothing from each end and grow again, over four ranges of keys; a clone, a cleared tree that is
   filled again and the two trees of a merge hold the rules too. The program reads the fields of the two instances,
   which no other program does. cicilang builds this file as C and cicilang++ as C++; both print tree_rules.expect.
   It has no twin */
#include <stdio.h>
#include <stdlib.h>
#include <set.pl>
#include <map.pl>
static unsigned seed = 1;
static unsigned rnd(void) { seed = seed * 1103515245u + 12345u; return seed >> 8; }
static size_t entries, nodes, checks;
static int leafdepth;
static void no(const char *what) { printf("NOT HELD: %s\n", what); exit(1); }
static void node_set(const set<int> *s, unsigned n, int depth, int isroot) {
    int c;
    if (n == 0 || n > s->top) no("a child's number is a node's of the arena");
    c = s->data[n - 1].n;
    if (s->data[n - 1].leaf > 1) no("no erased node is in the tree");
    if (c > 15 || (!isroot && c < 7) || (isroot && c < 1)) no("a node holds 7 to 15 entries, the root 1 at least");
    for (int i = 0; i + 1 < c; i++)
        if (!(s->data[n - 1].key[i] < s->data[n - 1].key[i + 1])) no("a node's keys are in their order");
    entries += (size_t)c;
    nodes++;
    if (s->data[n - 1].leaf) {
        if (leafdepth < 0) leafdepth = depth;
        else if (leafdepth != depth) no("the leaves stand at one depth");
        return;
    }
    for (int i = 0; i <= c; i++) node_set(s, s->data[n - 1].kid[i], depth + 1, 0);
}
static void rules_set(const set<int> *s) {
    size_t walked = 0, erased = 0;
    int have = 0, last = 0;
    entries = 0; nodes = 0; leafdepth = -1; checks++;
    if (s->root) node_set(s, (unsigned)s->root, 0, 1);
    if (entries != s->len || entries != size(s)) no("the entries are as many as the set says");
    for (size_t f = s->free; f; f = s->data[f - 1].kid[0]) {
        if (f > s->top || s->data[f - 1].leaf != 2) no("the chain holds erased nodes");
        if (++erased > s->top) no("the chain ends");
    }
    if (nodes + erased != s->top) no("each node of the arena is in the tree or in the chain");
    for (size_t p = begin(s); p != end(s); p = next(s, p)) {
        int k = key(s, p);
        if (have && !(last < k)) no("the places walk the keys in their order");
        last = k; have = 1; walked++;
    }
    if (walked != s->len) no("the places walk every entry");
    walked = 0;
    for (size_t p = prev(s, end(s)); p != end(s); p = prev(s, p)) walked++;
    if (walked != s->len) no("the places walk every entry back");
}
static void node_multimap(const multimap<int, long> *m, unsigned n, int depth, int isroot) {
    int c;
    if (n == 0 || n > m->top) no("a child's number is a node's of the arena");
    c = m->data[n - 1].n;
    if (m->data[n - 1].leaf > 1) no("no erased node is in the tree");
    if (c > 15 || (!isroot && c < 7) || (isroot && c < 1)) no("a node holds 7 to 15 entries, the root 1 at least");
    entries += (size_t)c;
    nodes++;
    if (m->data[n - 1].leaf) {
        if (leafdepth < 0) leafdepth = depth;
        else if (leafdepth != depth) no("the leaves stand at one depth");
        return;
    }
    for (int i = 0; i <= c; i++) node_multimap(m, m->data[n - 1].kid[i], depth + 1, 0);
}
/* in_order: the values grew with each insert, so equal keys in the order of their insert have their values so */
static void rules_multimap(const multimap<int, long> *m, int in_order) {
    size_t walked = 0, erased = 0;
    int have = 0, last = 0;
    long lastv = 0;
    entries = 0; nodes = 0; leafdepth = -1; checks++;
    if (m->root) node_multimap(m, (unsigned)m->root, 0, 1);
    if (entries != m->len || entries != size(m)) no("the entries are as many as the multimap says");
    for (size_t f = m->free; f; f = m->data[f - 1].kid[0]) {
        if (f > m->top || m->data[f - 1].leaf != 2) no("the chain holds erased nodes");
        if (++erased > m->top) no("the chain ends");
    }
    if (nodes + erased != m->top) no("each node of the arena is in the tree or in the chain");
    for (size_t p = begin(m); p != end(m); p = next(m, p)) {
        int k = key(m, p);
        long v = value(m, p);
        if (have && k < last) no("the places walk the keys in their order");
        if (have && in_order && k == last && !(lastv < v)) no("equal keys stand in the order of their insert");
        last = k; lastv = v; have = 1; walked++;
    }
    if (walked != m->len) no("the places walk every entry");
    walked = 0;
    for (size_t p = prev(m, end(m)); p != end(m); p = prev(m, p)) walked++;
    if (walked != m->len) no("the places walk every entry back");
}
int main(void) {
    int ranges[4] = {40, 700, 20000, 2000000};
    long n = 60000;
    for (int r = 0; r < 4; r++) {
        set<int> s;
        multimap<int, long> m;
        int range = ranges[r];
        size_t most = 0, most_m = 0, deepest = 0, deepest_m = 0, most_last;
        checks = 0;
        for (long i = 0; i < n; i++) {
            unsigned op = rnd() % 8;
            int k = (int)(rnd() % (unsigned)range);
            int mk = k % (range > 1000 ? 4001 : 97);      /* the multimap's key: many entries a key, or few */
            long part = i * 6 / n;     /* it grows; shrinks; grows; shrinks from its ends; grows again */
            if ((part == 1 || part == 3 || part == 4) && op < 6) op = 6;
            if (op < 5) { insert(s, k); insert(m, mk, i); }
            else if (op == 5) {
                size_t p = lower_bound(s, k);
                if (p != end(s)) erase_at(s, p);
                insert(m, mk, i);
            }
            else if (op == 6) {
                size_t p = lower_bound(m, mk);
                erase(s, k);
                if (p != end(m)) {
                    if (rnd() % 2 && next(m, p) != end(m)) p = next(m, p);
                    erase_at(m, p);
                }
                if (part == 3) {
                    size_t q = begin(s);
                    if (q != end(s)) erase_at(s, q);
                    q = prev(m, end(m));
                    if (q != end(m)) erase_at(m, q);
                }
                if (part == 4) {
                    size_t q = prev(s, end(s));
                    if (q != end(s)) erase_at(s, q);
                    q = begin(m);
                    if (q != end(m)) erase_at(m, q);
                }
            }
            else { erase(m, mk); insert(s, k); }
            if (i % 37 == 0 || size(s) < 40) {
                rules_set(&s);
                if (leafdepth > 0 && (size_t)leafdepth > deepest) deepest = (size_t)leafdepth;
                rules_multimap(&m, 1);
                if (leafdepth > 0 && (size_t)leafdepth > deepest_m) deepest_m = (size_t)leafdepth;
            }
            if (size(s) > most) most = size(s);
            if (size(m) > most_m) most_m = size(m);
        }
        most_last = size(m);
        c := clone(s);
        rules_set(&c);
        set<int> t;
        for (int i = 0; i < 300; i++) insert(t, (int)(rnd() % (unsigned)range));
        merge(c, t);
        rules_set(&c);
        rules_set(&t);
        clear(c);
        rules_set(&c);
        for (int i = 0; i < 300; i++) insert(c, i);
        rules_set(&c);
        swap(c, t);
        rules_set(&c);
        rules_set(&t);
        mc := clone(m);
        rules_multimap(&mc, 1);
        merge(mc, m);       /* each entry a second time, after the first of its key */
        rules_multimap(&mc, 0);
        rules_multimap(&m, 1);
        if (size(mc) != 2 * most_last || size(m) != 0) no("a multimap's merge takes every entry");
        printf("keys under %d: the rules held at %zu checks\n", range, checks);
        printf("  the set held %zu elements at most, its leaves %zu below the root; the multimap %zu entries, its "
               "leaves %zu below\n", most, deepest, most_m, deepest_m);
    }
    return 0;
}
