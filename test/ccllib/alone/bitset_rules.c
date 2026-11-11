/* THE RULES OF A BITSET of <bitset.pl> (0.286), checked from outside over a walk of chance, for the counts of bits at
   which a rule can break -- 1, 12, 63, 64, 65, 70, 128, 129 and 200: one bit, a part of a word, a word less one, a
   full word, a word and one, two words, two words and one, four words. After each step the set is held to a model, an
   array of a byte a bit: every bit by test and by [], count, any, none and all, to_ullong and to_ulong where no bit
   stands past their width; and THE BITS OF THE LAST WORD PAST THE COUNT ARE ZERO, which the program reads in the
   instance's own words -- a shift, a flip of all, a set of all, `~' and a set made of a number must leave none there.
   The steps: a bit set, taken away and flipped, by set, reset, flip and b[i] = x; all the bits set, taken away and
   flipped; a shift left and right by 0 to the count and past it, in its place and by value; `& | ^ ~' with a second
   set and their assignments; a set made of a number, and of a text of 0 to 10 characters more than the count, whose
   last character of those taken is the bit 0; `==' with the second set, and with a copy that differs in one bit of
   chance. cicilang builds this file as C and cicilang++ as C++; both print bitset_rules.expect. It has no twin */
#include <stdio.h>
#include <stdlib.h>
#include <bitset.pl>
static unsigned seed = 1;
static unsigned rnd(void) { seed = seed * 1103515245u + 12345u; return seed >> 8; }
static size_t checks;
static void no(int k, const char *what) { printf("NOT HELD for %d bits: %s\n", k, what); exit(1); }
#define RULES(K) \
static void held##K(const bitset<K> *b, const unsigned char *m) { \
    size_t n = 0; \
    unsigned long long x = 0; \
    int wide = 0; \
    checks++; \
    for (size_t i = 0; i < K; i++) { \
        if (test(b, i) != m[i] || (*b)[i] != m[i]) no(K, "each bit is the model's"); \
        n += m[i]; \
        if (m[i] && i < 64) x |= 1ULL << i; \
        if (m[i] && i >= 64) wide = 1; \
    } \
    if (!wide && to_ullong(b) != x) no(K, "to_ullong gives the bits as a number"); \
    if (!wide && (unsigned long)x == x && to_ulong(b) != x) no(K, "to_ulong gives the bits as a number"); \
    if (count(b) != n) no(K, "count is the count of the bits that are set"); \
    if (any(b) != (n > 0) || none(b) != (n == 0) || all(b) != (n == K)) no(K, "any, none and all go by the count"); \
    if (K % 64 && b->w[(K - 1) / 64] >> (K % 64)) no(K, "the bits of the last word past the count are zero"); \
} \
static void walk##K(long steps) { \
    bitset<K> b, c; \
    unsigned char m[K], mc[K], t[K]; \
    for (size_t i = 0; i < K; i++) m[i] = mc[i] = 0; \
    held##K(&b, m); \
    for (long step = 0; step < steps; step++) { \
        unsigned op = rnd() % 21; \
        size_t p = rnd() % K, s = rnd() % (K + 70); \
        if (op == 0) { set(b, p); m[p] = 1; } \
        else if (op == 1) { reset(b, p); m[p] = 0; } \
        else if (op == 2) { flip(b, p); m[p] ^= 1; } \
        else if (op == 3) { b[p] = (int)(s & 1); m[p] = (unsigned char)(s & 1); } \
        else if (op == 4) { set(b, p, (int)(s & 1)); m[p] = (unsigned char)(s & 1); } \
        else if (op == 5) { set(c); for (size_t i = 0; i < K; i++) mc[i] = 1; } \
        else if (op == 6) { reset(c); for (size_t i = 0; i < K; i++) mc[i] = 0; } \
        else if (op == 7) { flip(b); for (size_t i = 0; i < K; i++) m[i] ^= 1; } \
        else if (op == 8) { \
            b <<= s; \
            for (size_t i = 0; i < K; i++) t[i] = i >= s ? m[i - s] : 0; \
            for (size_t i = 0; i < K; i++) m[i] = t[i]; \
        } \
        else if (op == 9) { \
            b >>= s; \
            for (size_t i = 0; i < K; i++) t[i] = i + s < K ? m[i + s] : 0; \
            for (size_t i = 0; i < K; i++) m[i] = t[i]; \
        } \
        else if (op == 10) { \
            c = b << s; \
            for (size_t i = 0; i < K; i++) mc[i] = i >= s ? m[i - s] : 0; \
        } \
        else if (op == 11) { \
            c = b >> s; \
            for (size_t i = 0; i < K; i++) mc[i] = i + s < K ? m[i + s] : 0; \
        } \
        else if (op == 12) { b &= c; for (size_t i = 0; i < K; i++) m[i] &= mc[i]; } \
        else if (op == 13) { b |= c; for (size_t i = 0; i < K; i++) m[i] |= mc[i]; } \
        else if (op == 14) { b ^= c; for (size_t i = 0; i < K; i++) m[i] ^= mc[i]; } \
        else if (op == 15) { c = ~b; for (size_t i = 0; i < K; i++) mc[i] = !m[i]; } \
        else if (op == 16) { \
            c = b & ~c | c ^ b; \
            for (size_t i = 0; i < K; i++) mc[i] = (unsigned char)((m[i] & !mc[i]) | (mc[i] ^ m[i])); \
        } \
        else if (op == 17) { \
            unsigned long long x = ((unsigned long long)rnd() << 40) ^ ((unsigned long long)rnd() << 20) ^ rnd(); \
            c = x; \
            for (size_t i = 0; i < K; i++) mc[i] = i < 64 ? (unsigned char)(x >> i & 1) : 0; \
        } \
        else if (op == 18) { \
            int same = 1; \
            bitset<K> o = b; \
            for (size_t i = 0; i < K; i++) if (m[i] != mc[i]) same = 0; \
            if ((b == c) != same || (b != c) == same) no(K, "== tells whether each bit is the other's"); \
            flip(o, p); \
            if (b == o || !(b != o)) no(K, "== sees each bit"); \
            flip(o, p); \
            if (!(b == o) || b != o) no(K, "== sees each bit"); \
        } \
        else if (op == 19) { \
            char tx[K + 12]; \
            size_t len = s % (K + 11), mm = len < K ? len : K; \
            for (size_t i = 0; i < len; i++) tx[i] = (char)('0' + (rnd() & 1)); \
            tx[len] = 0; \
            c = tx; \
            for (size_t i = 0; i < K; i++) mc[i] = i < mm ? (unsigned char)(tx[mm - 1 - i] == '1') : 0; \
        } \
        else { c = b; for (size_t i = 0; i < K; i++) mc[i] = m[i]; } \
        held##K(&b, m); \
        held##K(&c, mc); \
    } \
}
RULES(1)
RULES(12)
RULES(63)
RULES(64)
RULES(65)
RULES(70)
RULES(128)
RULES(129)
RULES(200)
int main(void) {
    walk1(2000);
    walk12(4000);
    walk63(4000);
    walk64(4000);
    walk65(4000);
    walk70(4000);
    walk128(4000);
    walk129(4000);
    walk200(4000);
    printf("the rules held at %zu checks, for 1, 12, 63, 64, 65, 70, 128, 129 and 200 bits\n", checks);
    return 0;
}
