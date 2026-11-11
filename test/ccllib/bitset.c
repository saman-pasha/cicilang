/* <bitset.pl> (0.286; CCLLIB.md's phase 1a): the whole surface of ccllib's bitset, each function and each operator
   once at least, over sets of 12, 64, 70 and 200 bits -- one word, a full word, two words whose top one holds 6 bits,
   four words. cicilang builds this file as C and cicilang++ as C++; bitset.cpp is its twin over std::bitset, which
   clang++ builds over libc++: the three print the same lines, bitset.expect. With a count, `bitset 10000000', it
   makes that many steps of chance over three sets of 4096 bits -- a bit set, flipped and taken away, the sets
   and-ed, or-ed, xor-ed and shifted -- and prints what the steps left: the run that the costs time */
#include <stdio.h>
#include <stdlib.h>
#include <bitset.pl>
#define SHOW(K) static void show##K(const char *what, const bitset<K> *b) { \
    printf("%s ", what); \
    for (size_t i = K; i-- > 0; ) putchar('0' + test(b, i)); \
    printf(" %zu %d %d %d\n", count(b), any(b), none(b), all(b)); }
SHOW(12)
SHOW(64)
SHOW(70)
SHOW(200)
static unsigned seed = 1;
static unsigned rnd(void) { seed = seed * 1103515245u + 12345u; return seed >> 8; }
static int surface(void) {
    bitset<12> a;
    bitset<12> b = 0x0f0;
    bitset<12> c = "1010";
    bitset<12> d = 0xfffff;
    show12("born", &a);
    show12("of a number", &b);
    show12("of a text", &c);
    show12("cut", &d);
    printf("%zu %d %d %d %d\n", size(a), b[4], b[3], test(b, 7), test(b, 8));
    set(a, 3);
    a[5] = 1;
    a[11] = b[4];
    set(a, 0, 1);
    set(a, 5, 0);
    show12("set", &a);
    flip(a, 3);
    flip(a, 2);
    reset(a, 11);
    show12("flip", &a);
    flip(a);
    show12("flip all", &a);
    set(a);
    show12("set all", &a);
    reset(a);
    show12("reset all", &a);
    bitset<12> e = b & c, f = b | c, g = b ^ c, h = ~b;
    show12("and", &e);
    show12("or", &f);
    show12("xor", &g);
    show12("compl", &h);
    bitset<12> s1 = b << 3, s2 = b >> 5, s3 = b << 12, s4 = (b | c) << 1 >> 2, s5 = b >> 100;
    show12("shl 3", &s1);
    show12("shr 5", &s2);
    show12("shl 12", &s3);
    show12("chain", &s4);
    show12("shr 100", &s5);
    e &= f;
    e |= c;
    e ^= b;
    e <<= 2;
    e >>= 1;
    show12("assigned", &e);
    printf("%d %d %d %d %d\n", b == b, b == c, b != c, (b & c) == c, (b | ~b) == d);
    printf("%lu %llu\n", to_ulong(b), to_ullong(d));
    bitset<12> k = b;
    set(k, 0);
    k = k ^ b;
    printf("%d %d %zu\n", k == b, test(b, 0), count(k));
    k = 0x3;
    k = "110011";
    show12("assigned a text", &k);
    bitset<12> longer = "1111000011110000";
    show12("16 characters", &longer);
    /* 64 bits: the word's edge */
    bitset<64> w = 1;
    w <<= 63;
    show64("top", &w);
    bitset<64> v = ~w;
    show64("all but the top", &v);
    v <<= 1;
    v >>= 1;
    v = v >> 62 | w;
    show64("ends", &v);
    printf("%llu %d\n", to_ullong(v), w == v);
    /* 70 bits: two words, the top one of 6 bits */
    bitset<70> t = 1;
    t <<= 69;
    show70("top", &t);
    bitset<70> u = ~t;
    show70("all but the top", &u);
    u <<= 1;
    show70("shl 1", &u);
    u >>= 6;
    show70("shr 6", &u);
    t = 0xffffffffffffffffULL;
    t <<= 6;
    show70("a word up 6", &t);
    t >>= 64;
    show70("down 64", &t);
    printf("%llu %zu %d\n", to_ullong(t), count(u), (t ^ t) == (u & ~u));
    bitset<70> tx = "1000000000000000000000000000000000000000000000000000000000000000000001";
    show70("of 70 characters", &tx);
    /* 200 bits: four words */
    bitset<200> big;
    for (size_t i = 0; i < 200; i += 7) set(big, i);
    show200("each seventh", &big);
    big <<= 65;
    show200("shl 65", &big);
    big >>= 3;
    show200("shr 3", &big);
    bitset<200> other = ~big;
    other >>= 128;
    big ^= other << 64 | other;
    show200("mixed", &big);
    flip(big);
    printf("%zu %zu %d %d\n", count(big), size(big), all(big), big[199]);
    return 0;
}
static int many(long n) {
    bitset<4096> a, b, c;
    unsigned long h = 0;
    if (n < 1) n = 1;
    seed = 12345;
    for (long i = 0; i < n; i++) {
        unsigned op = rnd() % 12;
        size_t p = rnd() % 4096;
        if (op < 3) set(a, p);
        else if (op < 5) flip(b, p);
        else if (op == 5) reset(a, p);
        else if (op == 6) { c = a & b; h += count(c); }
        else if (op == 7) { c = a | b; h += count(c); }
        else if (op == 8) { c ^= a; h += (unsigned long)test(c, p); }
        else if (op == 9) { b <<= p % 130; h += count(b); }
        else if (op == 10) { b >>= p % 67; h += (unsigned long)any(b); }
        else { a |= ~c >> (p % 9); h += (unsigned long)(a == b) + (unsigned long)a[p]; }
        h = h * 31 + (unsigned long)b[p];
    }
    printf("%lu %zu %zu %zu\n", h, count(a), count(b), count(c));
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(atol(argv[1]));
    return surface();
}
