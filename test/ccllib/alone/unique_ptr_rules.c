/* THE RULES OF A UNIQUE_PTR of <memory.pl> (0.309), checked from outside: a model holds each unique_ptr's block as a
   number, 0 where it is empty, and its object's two values, and each call is held to it over a walk of chance of 4000
   steps on three unique_ptrs -- born empty; make_unique gives a block that no other holds, with the value that it was
   given, and make_unique() gives zero; *p and p->m are the object's place; release gives the block that get gave and
   empties p; reset frees and empties, reset(p, r) takes r; swap exchanges the blocks; each relation is the blocks'
   order, as C++ compares the pointers -- and then a move by an assignment, which gives the block whole, and a move
   into a function and out of one. A block that a call should free and does not is a leak, which valgrind sees in the
   three runs. cicilang builds this file as C and cicilang++ as C++; both print unique_ptr_rules.expect. It has no
   twin */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <memory.pl>
typedef struct cell { int v, w; } cell;
static long checks;
static void no(const char *what) { printf("NOT HELD: %s\n", what); exit(1); }
static void is(long got, long want, const char *what) { checks++; if (got != want) no(what); }
/* a unique_ptr's block as a number, and the model of three */
static uintptr_t at(const unique_ptr<cell> *u) { return (uintptr_t)get(*u); }
static uintptr_t m[3];
static int mv[3], mw[3];
/* each unique_ptr held to its model: its block, its object's values by get, by *p and by p->m, and no block twice */
static void held(unique_ptr<cell> *u[3]) {
    for (int i = 0; i < 3; i++) {
        is(at(u[i]) == m[i], 1, "a unique_ptr holds the block of its model");
        if (m[i]) {
            is(get(*u[i])->v, mv[i], "get gives the object");
            is((**u[i]).w, mw[i], "*p is the object");
            is((*u[i])->v, mv[i], "p->m is the object's member");
        }
        for (int j = 0; j < 3; j++)
            if (i != j && m[i]) is(m[i] == m[j], 0, "no block is held twice");
    }
}
/* each relation of two unique_ptrs is their blocks' */
static void related(unique_ptr<cell> *x, unique_ptr<cell> *y, uintptr_t a, uintptr_t b) {
    is(*x == *y, a == b, "== compares the blocks");
    is(*x != *y, a != b, "!= is the negation of ==");
    is(*x < *y, a < b, "< is the blocks' order");
    is(*x > *y, a > b, "> is the blocks' order the other way");
    is(*x <= *y, a <= b, "<= is the blocks' order");
    is(*x >= *y, a >= b, ">= is the blocks' order the other way");
}
static unique_ptr<cell> given(int v) {
    cell c = {v, -v};
    unique_ptr<cell> u = make_unique<cell>(c);
    return u;
}
static int kept(unique_ptr<cell> u) { return u->v; }
int main(void) {
    unique_ptr<cell> a, b, c;
    unique_ptr<cell> *u[3] = {&a, &b, &c};
    unsigned x = 2024;
    held(u);
    for (int step = 0; step < 4000; step++) {
        x = x * 1103515245u + 12345u;
        int i = (int)(x >> 8 & 0xffff) % 3, j = (int)(x >> 4 & 0xff) % 3, k = (int)(x >> 12 & 0x3ff);
        switch ((x >> 28) % 8) {
        case 0: case 1: {
            cell e = {k, -k};
            unique_ptr<cell> t = make_unique<cell>(e);
            uintptr_t n = at(&t);
            reset(*u[i], release(t));
            is(at(u[i]) == n, 1, "reset(p, r) takes r");
            m[i] = n; mv[i] = k; mw[i] = -k;
            break;
        }
        case 2: {
            unique_ptr<cell> t = make_unique<cell>();
            uintptr_t n = at(&t);
            reset(*u[i], release(t));
            m[i] = n; mv[i] = 0; mw[i] = 0;
            break;
        }
        case 3:
            reset(*u[i]);
            is(at(u[i]) == 0, 1, "reset empties");
            m[i] = 0;
            break;
        case 4:
            if (i == j) break;
            reset(*u[j], release(*u[i]));
            is(at(u[i]) == 0, 1, "release empties");
            m[j] = m[i]; mv[j] = mv[i]; mw[j] = mw[i];
            m[i] = 0;
            break;
        case 5:
            swap(*u[i], *u[j]);
            { uintptr_t t = m[i]; m[i] = m[j]; m[j] = t; }
            { int t = mv[i]; mv[i] = mv[j]; mv[j] = t; }
            { int t = mw[i]; mw[i] = mw[j]; mw[j] = t; }
            break;
        default:
            if (!m[i]) break;
            (*u[i])->v = k;
            (**u[i]).w += 1;
            mv[i] = k; mw[i] += 1;
            break;
        }
        held(u);
        for (int p = 0; p < 3; p++)
            for (int q = 0; q < 3; q++) related(u[p], u[q], m[p], m[q]);
    }
    /* the moves: a block goes whole by an assignment, into a function and out of one */
    uintptr_t n0 = at(&a);
    unique_ptr<cell> d = a;
    is(at(&d) == n0, 1, "a move by an assignment gives the block whole");
    unique_ptr<cell> e = given(9);
    is(e->v * 10 + e->w, 81, "a move out of a function gives the block that it made");
    is(kept(e), 9, "a move into a function gives the block");
    printf("the rules held at %ld checks, over a walk of chance of 4000 steps on three unique_ptrs\n", checks);
    return 0;
}
