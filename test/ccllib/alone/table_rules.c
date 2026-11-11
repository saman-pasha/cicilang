/* THE RULES OF THE TABLE of <unordered_set.pl> and <unordered_map.pl> (0.283), checked from outside over a walk of
   chance: the slots are as many as a power of two, and three of four at most hold an entry or an erased entry's
   mark; the table's counts are its slots'; `first' is the first entry's slot; no empty slot stands between an entry
   and the slot that its hash names, so a search finds it; a unique table holds a key once; a multimap's key counts
   its entries at its entry 0, and they have the numbers from 0 to that count. A set and a multimap grow, shrink to
   nothing and grow again, over four ranges of keys; a clone, a cleared table that is filled again, a table made
   again by rehash and reserve and the two tables of a merge hold the rules too. The program reads the fields of the
   two instances, which no other program does. cicilang builds this file as C and cicilang++ as C++; both print
   table_rules.expect. It has no twin */
#include <stdio.h>
#include <stdlib.h>
#include <unordered_set.pl>
#include <unordered_map.pl>
static unsigned seed = 1;
static unsigned rnd(void) { seed = seed * 1103515245u + 12345u; return seed >> 8; }
static size_t checks;
static void no(const char *what) { printf("NOT HELD: %s\n", what); exit(1); }
static void rules_set(const unordered_set<int> *s) {
    size_t live = 0, marks = 0, first = 0, walked = 0, found = 0, m = s->cap - 1;
    checks++;
    if (s->cap == 0) {
        if (s->len || s->used) no("a table of no slot holds nothing");
        return;
    }
    if (s->cap < 8 || (s->cap & m)) no("the slots are as many as a power of two, 8 at least");
    for (size_t j = 0; j < s->cap; j++) {
        if (s->data[j].h >= 2) {
            if (!live) first = j;
            live++;
            for (size_t i = s->data[j].h & m; i != j; i = (i + 1) & m)
                if (!s->data[i].h) no("no empty slot stands between an entry and its hash's slot");
            if (!contains(s, s->data[j].key)) no("a search finds each entry");
            found += count(s, s->data[j].key);
        } else if (s->data[j].h == 1) marks++;
    }
    if (live != s->len || live != size(s)) no("the entries are as many as the set says");
    if (live + marks != s->used) no("the entries and the marks are as many as `used' says");
    if (s->used * 4 > s->cap * 3) no("three slots of four at most hold an entry or a mark");
    if (live && first != s->first) no("`first' is the first entry's slot");
    if (found != live) no("a set holds a key once");
    for (size_t p = begin(s); p != end(s); p = next(s, p)) walked++;
    if (walked != live) no("the places walk every entry");
}
static void rules_multimap(const unordered_multimap<int, long> *t) {
    size_t live = 0, marks = 0, first = 0, walked = 0, counted = 0, m = t->cap - 1;
    checks++;
    if (t->cap == 0) {
        if (t->len || t->used) no("a table of no slot holds nothing");
        return;
    }
    if (t->cap < 8 || (t->cap & m)) no("the slots are as many as a power of two, 8 at least");
    for (size_t j = 0; j < t->cap; j++) {
        if (t->data[j].h >= 2) {
            int k = t->data[j].key;
            if (!live) first = j;
            live++;
            for (size_t i = t->data[j].h & m; i != j; i = (i + 1) & m)
                if (!t->data[i].h) no("no empty slot stands between an entry and its hash's slot");
            if (t->data[j].dup & 0x80000000u) {
                size_t c = t->data[j].dup & 0x7fffffffu;
                if (c == 0 || c != count(t, k)) no("a key's entry 0 counts the key's entries");
                counted += c;
                for (size_t i = 0; i < c; i++) {
                    size_t p = find(t, k, i);
                    if (p == end(t) || key(t, p) != k) no("a key's entries have the numbers from 0 to its count");
                }
            } else if (t->data[j].dup == 0 || t->data[j].dup >= count(t, k)) {
                no("an entry's number is under its key's count");
            }
        } else if (t->data[j].h == 1) marks++;
    }
    if (live != t->len || live != size(t)) no("the entries are as many as the multimap says");
    if (live + marks != t->used) no("the entries and the marks are as many as `used' says");
    if (t->used * 4 > t->cap * 3) no("three slots of four at most hold an entry or a mark");
    if (live && first != t->first) no("`first' is the first entry's slot");
    if (counted != live) no("each entry is one of its key's counted entries");
    for (size_t p = begin(t); p != end(t); p = next(t, p)) walked++;
    if (walked != live) no("the places walk every entry");
}
int main(void) {
    int ranges[4] = {40, 700, 20000, 2000000};
    long n = 60000;
    for (int r = 0; r < 4; r++) {
        unordered_set<int> s;
        unordered_multimap<int, long> m;
        int range = ranges[r];
        size_t most = 0, most_m = 0, slots = 0;
        checks = 0;
        for (long i = 0; i < n; i++) {
            unsigned op = rnd() % 8;
            int k = (int)(rnd() % (unsigned)range);
            int mk = k % (range > 1000 ? 4001 : 97);      /* the multimap's key: many entries a key, or few */
            long part = i * 6 / n;     /* it grows; shrinks; grows; shrinks by walks that erase; grows again */
            if ((part == 1 || part == 3 || part == 4) && op < 6) op = 6;
            if (op < 5) { insert(s, k); insert(m, mk, i); }
            else if (op == 5) {
                size_t p = find(s, k);
                if (p != end(s)) erase_at(s, p);
                insert(m, mk, i);
            }
            else if (op == 6) {
                size_t c = count(m, mk);
                erase(s, k);
                if (c) erase_at(m, find(m, mk, rnd() % c));
                if (part == 3) {
                    size_t q = begin(s);
                    if (q != end(s)) erase_at(s, q);
                    q = begin(m);
                    if (q != end(m)) erase_at(m, q);
                }
                if (part == 4 && i % 16 == 0) {
                    /* a walk that erases one entry in three */
                    size_t met = 0, before = size(s), at = 0;
                    for (size_t q = begin(s); q != end(s); at++) {
                        met++;
                        if (at % 3 == 0) q = erase_at(s, q); else q = next(s, q);
                    }
                    if (met != before) no("a walk that erases meets each entry once");
                    met = 0; before = size(m); at = 0;
                    for (size_t q = begin(m); q != end(m); at++) {
                        met++;
                        if (at % 3 == 0) q = erase_at(m, q); else q = next(m, q);
                    }
                    if (met != before) no("a walk that erases meets each entry of a multimap once");
                }
            }
            else { erase(m, mk); insert(s, k); }
            if (i % 37 == 0 || size(s) < 40) { rules_set(&s); rules_multimap(&m); }
            if (size(s) > most) most = size(s);
            if (size(m) > most_m) most_m = size(m);
            if (bucket_count(s) > slots) slots = bucket_count(s);
        }
        size_t last_m = size(m);
        c := clone(s);
        rules_set(&c);
        unordered_set<int> t;
        for (int i = 0; i < 300; i++) insert(t, (int)(rnd() % (unsigned)range));
        merge(c, t);
        rules_set(&c);
        rules_set(&t);
        clear(c);
        rules_set(&c);
        for (int i = 0; i < 300; i++) insert(c, i);
        rules_set(&c);
        rehash(c, 0);
        rules_set(&c);
        reserve(c, 5000);
        rules_set(&c);
        swap(c, t);
        rules_set(&c);
        rules_set(&t);
        mc := clone(m);
        rules_multimap(&mc);
        merge(mc, m);       /* each entry a second time */
        rules_multimap(&mc);
        rules_multimap(&m);
        if (size(mc) != 2 * last_m || size(m) != 0) no("a multimap's merge takes every entry");
        rehash(mc, 0);
        rules_multimap(&mc);
        printf("keys under %d: the rules held at %zu checks\n", range, checks);
        printf("  the set held %zu elements at most, in %zu slots at most; the multimap %zu entries\n", most, slots,
               most_m);
    }
    return 0;
}
