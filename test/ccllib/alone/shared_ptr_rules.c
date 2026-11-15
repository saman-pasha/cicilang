/* THE RULES OF A SHARED_PTR of <memory.pl> (1.1.3), checked from outside: the model holds each shared_ptr's block as the
   address that get gives (0 where it is empty), its object's two values, and the count of the handles that share it.
   Each call is held to it over a walk of chance of 4000 steps on three shared_ptrs -- born empty; make_shared gives a
   block that one handle holds, with the value that it was given, and make_shared() gives zero; clone gives a second
   handle of the same block and its count one more; reset gives the block up and empty; reset(p, x) gives it up and takes
   a block of x; swap exchanges the blocks; use_count is the count and unique says it is one; *p and p->m are the
   object's place, which every handle of the block sees; each relation is the blocks' order, as C++ compares the
   pointers -- and then a move by an assignment, which gives the block whole, and a move into a function and out of one.
   A block that a call should free and does not is a leak, which valgrind sees in the three runs. cicilang builds this
   file as C and cicilang++ as C++; both print shared_ptr_rules.expect. It has no twin */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <memory.pl>
typedef struct cell { int v, w; } cell;
static long checks;
static void no(const char *what) { printf("NOT HELD: %s\n", what); exit(1); }
static void is(long got, long want, const char *what) { checks++; if (got != want) no(what); }
/* a shared_ptr's block as the address that get gives, and the model of three: each handle's block, the block's two
   values, and the count is how many of the three hold it */
static uintptr_t at(const shared_ptr<cell> *u) { return (uintptr_t)get(*u); }
static uintptr_t m[3];
static int mv[3], mw[3];
static int refs(int i) {
    int n = 0;
    for (int j = 0; j < 3; j++) if (m[i] && m[j] == m[i]) n++;
    return n;
}
static int v_of(uintptr_t n) { for (int j = 0; j < 3; j++) if (m[j] == n) return mv[j]; return 0; }
static int w_of(uintptr_t n) { for (int j = 0; j < 3; j++) if (m[j] == n) return mw[j]; return 0; }
static void take(int i, uintptr_t n) { int v = v_of(n), w = w_of(n); m[i] = n; mv[i] = v; mw[i] = w; }
static void setv(int i, int v, int w) {
    for (int j = 0; j < 3; j++) if (m[j] && m[j] == m[i]) { mv[j] = v; mw[j] = w; }
}
/* each shared_ptr held to its model: its block, its object's values by get, by *p and by p->m, the count of the
   handles that hold it, and unique */
static void held(shared_ptr<cell> *u[3]) {
    for (int i = 0; i < 3; i++) {
        is(at(u[i]) == m[i], 1, "a shared_ptr holds the block of its model");
        is(use_count(*u[i]), refs(i), "use_count is the count of the handles that hold the block");
        is(unique(*u[i]), refs(i) == 1, "unique says the count is one");
        if (m[i]) {
            is(get(*u[i])->v, mv[i], "get gives the object");
            is((**u[i]).w, mw[i], "*p is the object");
            is((*u[i])->v, mv[i], "p->m is the object's member");
        } else {
            is(get(*u[i]) == 0, 1, "an empty shared_ptr's get is null");
        }
    }
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++)
            if (m[i] && m[j] == m[i]) is(mv[i] + mw[i] * 1000, mv[j] + mw[j] * 1000, "two handles of a block see one object");
}
/* each relation of two shared_ptrs is their blocks' */
static void related(shared_ptr<cell> *x, shared_ptr<cell> *y, uintptr_t a, uintptr_t b) {
    is(*x == *y, a == b, "== compares the blocks");
    is(*x != *y, a != b, "!= is the negation of ==");
    is(*x < *y, a < b, "< is the blocks' order");
    is(*x > *y, a > b, "> is the blocks' order the other way");
    is(*x <= *y, a <= b, "<= is the blocks' order");
    is(*x >= *y, a >= b, ">= is the blocks' order the other way");
}
/* clone gives a second handle of the block, which a move into a local takes */
static shared_ptr<cell> share(const shared_ptr<cell> *from) { return clone(*from); }
static shared_ptr<cell> given(int v) {
    cell c = {v, -v};
    shared_ptr<cell> u = make_shared<cell>(c);
    return u;
}
static int kept(shared_ptr<cell> u) { return u->v; }
int main(void) {
    shared_ptr<cell> a, b, c;
    shared_ptr<cell> *u[3] = {&a, &b, &c};
    unsigned x = 2024;
    held(u);
    for (int step = 0; step < 4000; step++) {
        x = x * 1103515245u + 12345u;
        int k = (int)(x >> 12 & 0x3ff), h = (int)(x >> 8 & 0xffff) % 3;
        switch ((x >> 28) % 10) {
        case 0: case 1: {
            cell e = {k, -k};
            if (h == 0) { a = make_shared<cell>(e); take(0, at(&a)); mv[0] = k; mw[0] = -k; }
            else if (h == 1) { b = make_shared<cell>(e); take(1, at(&b)); mv[1] = k; mw[1] = -k; }
            else { c = make_shared<cell>(e); take(2, at(&c)); mv[2] = k; mw[2] = -k; }
            break;
        }
        case 2:
            if (h == 0) { c = share(&a); take(2, at(&c)); }
            else if (h == 1) { a = share(&b); take(0, at(&a)); }
            else { b = share(&c); take(1, at(&b)); }
            break;
        case 3:
            if (h == 0) { b = share(&a); take(1, at(&b)); }
            else if (h == 1) { c = share(&b); take(2, at(&c)); }
            else { a = share(&c); take(0, at(&a)); }
            break;
        case 4:
            if (h == 0) { reset(a); m[0] = 0; }
            else if (h == 1) { reset(b); m[1] = 0; }
            else { reset(c); m[2] = 0; }
            break;
        case 5: {
            cell e = {k, -k};
            if (h == 0) { reset(a, e); take(0, at(&a)); mv[0] = k; mw[0] = -k; }
            else if (h == 1) { reset(b, e); take(1, at(&b)); mv[1] = k; mw[1] = -k; }
            else { reset(c, e); take(2, at(&c)); mv[2] = k; mw[2] = -k; }
            break;
        }
        case 6:
            swap(a, b);
            { uintptr_t t = m[0]; m[0] = m[1]; m[1] = t; }
            { int t = mv[0]; mv[0] = mv[1]; mv[1] = t; }
            { int t = mw[0]; mw[0] = mw[1]; mw[1] = t; }
            break;
        case 7:
            swap(b, c);
            { uintptr_t t = m[1]; m[1] = m[2]; m[2] = t; }
            { int t = mv[1]; mv[1] = mv[2]; mv[2] = t; }
            { int t = mw[1]; mw[1] = mw[2]; mw[2] = t; }
            break;
        default:
            if (h == 0) { if (!m[0]) break; a->v = k; a->w += 1; setv(0, k, mw[0] + 1); }
            else if (h == 1) { if (!m[1]) break; b->v = k; (*b).w += 1; setv(1, k, mw[1] + 1); }
            else { if (!m[2]) break; c->v = k; c->w += 1; setv(2, k, mw[2] + 1); }
            break;
        }
        held(u);
        for (int p = 0; p < 3; p++)
            for (int q = 0; q < 3; q++) related(u[p], u[q], m[p], m[q]);
    }
    /* the moves: a block goes whole by an assignment, into a function and out of one */
    { uintptr_t n = m[0]; int v = mv[0], w = mw[0];
      c = a;
      is(at(&c), n, "a move by an assignment gives the block whole");
      m[2] = n; mv[2] = v; mw[2] = w; m[0] = 0; }
    shared_ptr<cell> e = given(9);
    is(e->v * 10 + e->w, 81, "a move out of a function gives the block that it made");
    is(kept(e), 9, "a move into a function gives the block");
    /* make_shared() is the object's zero, and an emptied handle's block is another's no more */
    b = make_shared<cell>();
    is(b->v + b->w, 0, "make_shared() gives the object's zero");
    printf("the rules held at %ld checks, over a walk of chance of 4000 steps on three shared_ptrs\n", checks);
    return 0;
}
