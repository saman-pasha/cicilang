/* THE RULES OF AN OPTIONAL of <optional.pl> (0.300), checked from outside over a walk of chance: eight optional
   numbers, held after each step to a model of a flag and a number each. Each optional's has_value, value and value_or
   are the model's; and EACH RELATION IS C++'S, by the standard's own words and not by the module's way to them --
   [optional.relops] between two optionals, [optional.comp.with.t] with a number on either side, and [optional.nullops]
   with nullopt on either side, each of the six operators. The numbers are from 0 to 5, so that two optionals are equal
   often. The steps: a number assigned, nullopt assigned, emplace and a write through the place it gives back, reset,
   swap, a copy of another, an optional born in a block and assigned, and a copy changed by emplace, which leaves its
   source as it was. cicilang builds this file as C and cicilang++ as C++; both print optional_rules.expect. It has no
   twin */
#include <stdio.h>
#include <stdlib.h>
#include <optional.pl>
#define K 8
static unsigned seed = 1;
static unsigned rnd(void) { seed = seed * 1103515245u + 12345u; return seed >> 8; }
static long checks;
static void no(const char *what) { printf("NOT HELD: %s\n", what); exit(1); }
static void is(int got, int want, const char *what) { checks++; if (got != want) no(what); }
static void held(const optional<int> *o, const int *mh, const int *mv) {
    for (int i = 0; i < K; i++) {
        is(has_value(o[i]), mh[i], "has_value is the model's flag");
        if (mh[i]) is(value(o[i]), mv[i], "value is the model's number");
        is(value_or(o[i], -7), mh[i] ? mv[i] : -7, "value_or is the number, else the default");
        for (int j = 0; j < K; j++) {
            int x = mh[i], y = mh[j], a = mv[i], b = mv[j];
            is(o[i] == o[j], x != y ? 0 : !x ? 1 : a == b, "[optional.relops] ==");
            is(o[i] != o[j], x != y ? 1 : !x ? 0 : a != b, "[optional.relops] !=");
            is(o[i] < o[j], !y ? 0 : !x ? 1 : a < b, "[optional.relops] <");
            is(o[i] > o[j], !x ? 0 : !y ? 1 : a > b, "[optional.relops] >");
            is(o[i] <= o[j], !x ? 1 : !y ? 0 : a <= b, "[optional.relops] <=");
            is(o[i] >= o[j], !y ? 1 : !x ? 0 : a >= b, "[optional.relops] >=");
        }
        for (int v = -1; v <= 6; v++) {
            int x = mh[i], a = mv[i];
            is(o[i] == v, x ? a == v : 0, "[optional.comp.with.t] x == v");
            is(o[i] != v, x ? a != v : 1, "[optional.comp.with.t] x != v");
            is(o[i] < v, x ? a < v : 1, "[optional.comp.with.t] x < v");
            is(o[i] > v, x ? a > v : 0, "[optional.comp.with.t] x > v");
            is(o[i] <= v, x ? a <= v : 1, "[optional.comp.with.t] x <= v");
            is(o[i] >= v, x ? a >= v : 0, "[optional.comp.with.t] x >= v");
            is(v == o[i], x ? v == a : 0, "[optional.comp.with.t] v == x");
            is(v != o[i], x ? v != a : 1, "[optional.comp.with.t] v != x");
            is(v < o[i], x ? v < a : 0, "[optional.comp.with.t] v < x");
            is(v > o[i], x ? v > a : 1, "[optional.comp.with.t] v > x");
            is(v <= o[i], x ? v <= a : 0, "[optional.comp.with.t] v <= x");
            is(v >= o[i], x ? v >= a : 1, "[optional.comp.with.t] v >= x");
        }
        is(o[i] == nullopt, !mh[i], "[optional.nullops] x == nullopt");
        is(o[i] != nullopt, mh[i], "[optional.nullops] x != nullopt");
        is(o[i] < nullopt, 0, "[optional.nullops] x < nullopt");
        is(o[i] > nullopt, mh[i], "[optional.nullops] x > nullopt");
        is(o[i] <= nullopt, !mh[i], "[optional.nullops] x <= nullopt");
        is(o[i] >= nullopt, 1, "[optional.nullops] x >= nullopt");
        is(nullopt == o[i], !mh[i], "[optional.nullops] nullopt == x");
        is(nullopt != o[i], mh[i], "[optional.nullops] nullopt != x");
        is(nullopt < o[i], mh[i], "[optional.nullops] nullopt < x");
        is(nullopt > o[i], 0, "[optional.nullops] nullopt > x");
        is(nullopt <= o[i], 1, "[optional.nullops] nullopt <= x");
        is(nullopt >= o[i], !mh[i], "[optional.nullops] nullopt >= x");
    }
}
int main(void) {
    optional<int> o[K];
    int mh[K], mv[K];
    for (int i = 0; i < K; i++) { mh[i] = 0; mv[i] = 0; }
    held(o, mh, mv);
    for (long step = 0; step < 4000; step++) {
        int i = (int)(rnd() % K), j = (int)(rnd() % K), v = (int)(rnd() % 6);
        unsigned op = rnd() % 8;
        if (op == 0) { o[i] = v; mh[i] = 1; mv[i] = v; }
        else if (op == 1) { o[i] = nullopt; mh[i] = 0; }
        else if (op == 2) { *emplace(o[i], v) += 1; mh[i] = 1; mv[i] = v + 1; }
        else if (op == 3) { reset(o[i]); mh[i] = 0; }
        else if (op == 4) {
            int h = mh[i], w = mv[i];
            swap(o[i], o[j]);
            mh[i] = mh[j]; mv[i] = mv[j]; mh[j] = h; mv[j] = w;
        }
        else if (op == 5) { o[i] = o[j]; mh[i] = mh[j]; mv[i] = mv[j]; }
        else if (op == 6) {
            optional<int> t;
            is(has_value(t), 0, "an optional born in a block has no value");
            t = v;
            o[i] = t;
            mh[i] = 1; mv[i] = v;
        }
        else {
            q := o[i];
            emplace(q, 5 - v);
            is(value(q), 5 - v, "emplace gives a copy its own value");
        }
        held(o, mh, mv);
    }
    printf("the rules held at %ld checks, over %d optional numbers and 4000 steps\n", checks, K);
    return 0;
}
