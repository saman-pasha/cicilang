/* THE RULES OF A VARIANT of <variant.pl> (0.308), checked from outside over every case and not over a walk of chance:
   each variant of an int of 0, 1 and 2 or of a double of 0, 1, 2 and a NaN against each, and each variant of a
   monostate or of an int of 0 and 1 against each. EACH RELATION IS C++20'S, by the standard's words and not by the
   module's way to them ([variant.relops]: `==' is false where the indices differ, else the alternatives' `=='; `<',
   `>', `<=' and `>=' go by the indices where they differ, else by the alternatives' own relation, so that a NaN makes
   all but `!=' false; two monostates are equal). A variant of a value holds that value's alternative, holds_alternative
   and get_if answer by the index, get and emplace give the alternative's place, swap exchanges the indices and the
   values, a copy keeps its own, a variant is born holding its first alternative's zero, and visit calls the function
   of the alternative that it holds, with its value or its place, and gives that function's result. A variant of 255
   alternatives, the most that its index of a byte takes, holds its last. cicilang builds this file as C and cicilang++
   as C++; both print variant_rules.expect. It has no twin */
#include <stdio.h>
#include <stdlib.h>
#include <variant.pl>
static long checks;
static void no(const char *what) { printf("NOT HELD: %s\n", what); exit(1); }
static void is(int got, int want, const char *what) { checks++; if (got != want) no(what); }
/* a case as the rules see it: the index of its alternative, and its value */
typedef struct model { int index; double value; } model;
/* which visitor the last visit called, and with what */
static int seen;
static double seen_value;
static int tell_int(int x) { seen = 0; seen_value = x; return 10 + x; }
static int tell_double(double x) { seen = 1; seen_value = x; return 20; }
static void touch_int(int *x) { seen = 0; *x += 5; }
static void touch_double(double *x) { seen = 1; *x += 0.5; }
/* the six relations of two cases, held to their models by the standard's words */
static void held(variant<int, double> a, variant<int, double> b, model x, model y) {
    int same = x.index == y.index;
    int eq = same && x.value == y.value;
    is(a == b, eq, "== is false where the indices differ, else the alternatives' ==");
    is(a != b, !eq, "!= is the negation of ==");
    is(a < b, same ? x.value < y.value : x.index < y.index, "< goes by the indices, else by the alternatives' <");
    is(a > b, same ? x.value > y.value : x.index > y.index, "> goes by the indices, else by the alternatives' >");
    is(a <= b, same ? x.value <= y.value : x.index < y.index, "<= goes by the indices, else by the alternatives' <=");
    is(a >= b, same ? x.value >= y.value : x.index > y.index, ">= goes by the indices, else by the alternatives' >=");
}
static void relations(void) {
    volatile double zero = 0.0;
    model ms[7] = {{0, 0}, {0, 1}, {0, 2}, {1, 0}, {1, 1}, {1, 2}, {1, 0}};
    variant<int, double> vs[7];
    ms[6].value = zero / zero;
    for (int i = 0; i < 7; i++) {
        if (ms[i].index == 0) vs[i] = (int)ms[i].value; else vs[i] = ms[i].value;
        is(index(vs[i]), ms[i].index, "a variant of a value holds that value's alternative");
    }
    for (int i = 0; i < 7; i++)
        for (int j = 0; j < 7; j++) held(vs[i], vs[j], ms[i], ms[j]);
}
static void monostates(void) {
    model ms[4] = {{0, 0}, {0, 0}, {1, 0}, {1, 1}};
    variant<monostate, int> vs[4];
    vs[2] = 0;
    vs[3] = 1;
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++) {
            model x = ms[i], y = ms[j];
            int same = x.index == y.index;
            int eq = same && x.value == y.value;
            is(vs[i] == vs[j], eq, "two monostates are equal");
            is(vs[i] != vs[j], !eq, "!= is the negation of ==, over monostates");
            is(vs[i] < vs[j], same ? x.value < y.value : x.index < y.index, "no monostate is before another");
            is(vs[i] > vs[j], same ? x.value > y.value : x.index > y.index, "no monostate is after another");
            is(vs[i] <= vs[j], same ? x.value <= y.value : x.index < y.index, "<= over monostates");
            is(vs[i] >= vs[j], same ? x.value >= y.value : x.index > y.index, ">= over monostates");
        }
}
static void places(void) {
    for (int i = 0; i < 100; i++) {
        variant<int, double, char> v;
        is(index(v), 0, "a variant is born holding its first alternative");
        is(get<0>(v), 0, "and that alternative is born zero");
        v = i;
        is(index(v), 0, "a variant of an int holds the int");
        is(holds_alternative<int>(v), 1, "holds_alternative answers by the index");
        is(holds_alternative<double>(v) + holds_alternative<char>(v), 0, "holds_alternative of another is false");
        is(get<int>(v), i, "get gives the value");
        is(get_if<int>(&v) == &get<0>(v), 1, "get_if gives the alternative's place");
        is(get_if<double>(&v) == 0 && get_if<2>(&v) == 0, 1, "get_if of another alternative gives a null pointer");
        v = i / 4.0;
        is(index(v), 1, "a variant of a double holds the double");
        is(get<1>(v) == i / 4.0, 1, "get by an index gives the value");
        is(get_if<int>(&v) == 0, 1, "get_if of the alternative that it held before gives a null pointer");
        v = (char)('a' + i % 26);
        is(index(v), 2, "a variant of a char holds the char");
        is(get<char>(v), 'a' + i % 26, "get by the type gives the value");
        emplace<0>(v, 3 * i) += 1;
        is(index(v), 0, "emplace stores its alternative");
        is(get<0>(v), 3 * i + 1, "and gives its place");
        *get_if<0>(&v) = 7 + i;
        is(get<int>(v), 7 + i, "the place that get_if gives is the alternative's");
        get<0>(v) += 1;
        is(get<int>(v), 8 + i, "the place that get gives is the alternative's");
        variant<int, double, char> w = 0.5 * i;
        c := v;
        get<0>(c) = -1;
        is(get<0>(v), 8 + i, "a copy is its own");
        swap(v, w);
        is(index(v), 1, "swap exchanges the indices");
        is(get<1>(v) == 0.5 * i, 1, "and the values");
        is(index(w), 0, "swap exchanges the indices, the other way");
        is(get<0>(w), 8 + i, "and the values, the other way");
        variant<int, double> t = i;
        is(visit<tell>(t), 10 + i, "visit gives the result of the function of the alternative that it holds");
        is(seen, 0, "visit calls the function of the alternative that it holds");
        is(seen_value == i, 1, "with its value");
        t = i + 0.25;
        is(visit<tell>(t), 20, "visit gives the result of the other alternative's function");
        is(seen, 1, "visit calls the other alternative's function");
        is(seen_value == i + 0.25, 1, "with its value, the other alternative's");
        visit<touch>(t);
        is(seen == 1 && get<1>(t) == i + 0.75, 1, "visit hands a function of a pointer the alternative's place");
        t = i;
        visit<touch>(t);
        is(seen == 0 && get<0>(t) == i + 5, 1, "and so for the other alternative");
        is(valueless_by_exception(t), 0, "a variant is never valueless");
    }
}
/* the most alternatives: 255, made by macros, the last a double */
#define I8 int, int, int, int, int, int, int, int
#define I64 I8, I8, I8, I8, I8, I8, I8, I8
static void most(void) {
    variant<I64, I64, I64, I8, I8, I8, I8, I8, I8, I8, int, int, int, int, int, int, double> v;
    is(index(v), 0, "a variant of 255 alternatives is born holding its first");
    emplace<254>(v, 2.5);
    is(index(v), 254, "a variant of 255 alternatives holds its last, of the index 254");
    is(get<254>(v) == 2.5, 1, "and its last alternative's value");
}
int main(void) {
    relations();
    monostates();
    places();
    most();
    printf("the rules held at %ld checks, over every variant of numbers, of a NaN and of monostates\n", checks);
    return 0;
}
