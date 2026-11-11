// the twin of bitset.c over std::bitset: clang++ builds it over libc++, and it prints bitset.expect
#include <bitset>
#include <cstdio>
#include <cstdlib>
template <size_t K> static void show(const char *what, const std::bitset<K> &b) {
    printf("%s ", what);
    for (size_t i = K; i-- > 0; ) putchar('0' + (int)b.test(i));
    printf(" %zu %d %d %d\n", b.count(), (int)b.any(), (int)b.none(), (int)b.all());
}
static unsigned seed = 1;
static unsigned rnd(void) { seed = seed * 1103515245u + 12345u; return seed >> 8; }
static int surface(void) {
    std::bitset<12> a;
    std::bitset<12> b(0x0f0);
    std::bitset<12> c("1010");
    std::bitset<12> d(0xfffff);
    show("born", a);
    show("of a number", b);
    show("of a text", c);
    show("cut", d);
    printf("%zu %d %d %d %d\n", a.size(), (int)b[4], (int)b[3], (int)b.test(7), (int)b.test(8));
    a.set(3);
    a[5] = 1;
    a[11] = b[4];
    a.set(0, 1);
    a.set(5, 0);
    show("set", a);
    a.flip(3);
    a.flip(2);
    a.reset(11);
    show("flip", a);
    a.flip();
    show("flip all", a);
    a.set();
    show("set all", a);
    a.reset();
    show("reset all", a);
    std::bitset<12> e = b & c, f = b | c, g = b ^ c, h = ~b;
    show("and", e);
    show("or", f);
    show("xor", g);
    show("compl", h);
    std::bitset<12> s1 = b << 3, s2 = b >> 5, s3 = b << 12, s4 = (b | c) << 1 >> 2, s5 = b >> 100;
    show("shl 3", s1);
    show("shr 5", s2);
    show("shl 12", s3);
    show("chain", s4);
    show("shr 100", s5);
    e &= f;
    e |= c;
    e ^= b;
    e <<= 2;
    e >>= 1;
    show("assigned", e);
    printf("%d %d %d %d %d\n", (int)(b == b), (int)(b == c), (int)(b != c), (int)((b & c) == c), (int)((b | ~b) == d));
    printf("%lu %llu\n", b.to_ulong(), d.to_ullong());
    std::bitset<12> k = b;
    k.set(0);
    k = k ^ b;
    printf("%d %d %zu\n", (int)(k == b), (int)b.test(0), k.count());
    k = 0x3;
    k = std::bitset<12>("110011");
    show("assigned a text", k);
    std::bitset<12> longer("1111000011110000");
    show("16 characters", longer);
    std::bitset<64> w(1);
    w <<= 63;
    show("top", w);
    std::bitset<64> v = ~w;
    show("all but the top", v);
    v <<= 1;
    v >>= 1;
    v = v >> 62 | w;
    show("ends", v);
    printf("%llu %d\n", v.to_ullong(), (int)(w == v));
    std::bitset<70> t(1);
    t <<= 69;
    show("top", t);
    std::bitset<70> u = ~t;
    show("all but the top", u);
    u <<= 1;
    show("shl 1", u);
    u >>= 6;
    show("shr 6", u);
    t = 0xffffffffffffffffULL;
    t <<= 6;
    show("a word up 6", t);
    t >>= 64;
    show("down 64", t);
    printf("%llu %zu %d\n", t.to_ullong(), u.count(), (int)((t ^ t) == (u & ~u)));
    std::bitset<70> tx("1000000000000000000000000000000000000000000000000000000000000000000001");
    show("of 70 characters", tx);
    std::bitset<200> big;
    for (size_t i = 0; i < 200; i += 7) big.set(i);
    show("each seventh", big);
    big <<= 65;
    show("shl 65", big);
    big >>= 3;
    show("shr 3", big);
    std::bitset<200> other = ~big;
    other >>= 128;
    big ^= other << 64 | other;
    show("mixed", big);
    big.flip();
    printf("%zu %zu %d %d\n", big.count(), big.size(), (int)big.all(), (int)big[199]);
    return 0;
}
static int many(long n) {
    std::bitset<4096> a, b, c;
    unsigned long h = 0;
    if (n < 1) n = 1;
    seed = 12345;
    for (long i = 0; i < n; i++) {
        unsigned op = rnd() % 12;
        size_t p = rnd() % 4096;
        if (op < 3) a.set(p);
        else if (op < 5) b.flip(p);
        else if (op == 5) a.reset(p);
        else if (op == 6) { c = a & b; h += c.count(); }
        else if (op == 7) { c = a | b; h += c.count(); }
        else if (op == 8) { c ^= a; h += (unsigned long)c.test(p); }
        else if (op == 9) { b <<= p % 130; h += b.count(); }
        else if (op == 10) { b >>= p % 67; h += (unsigned long)b.any(); }
        else { a |= ~c >> (p % 9); h += (unsigned long)(a == b) + (unsigned long)a[p]; }
        h = h * 31 + (unsigned long)b[p];
    }
    printf("%lu %zu %zu %zu\n", h, a.count(), b.count(), c.count());
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(atol(argv[1]));
    return surface();
}
