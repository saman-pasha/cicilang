/* OPERATORS ON INSTANCES, PART 2 (0.284; what 0.266 left): `& | ^' and the unary `~' over a set of bits, a shift by a
   number, the compound assignments in the object's place, `b[i]' as a value and `b[i] = x'; `%', the unary `-' and
   the arithmetic assignments over a number; and a function named with the word of its right operand's type, which
   goes before the plain one (`x + 3', `x == 2', `x += 10'). cicilang++ builds this file too */
#include <stdio.h>
#include <stddef.h>
#include "topers2.pl"
int main(void) {
    bits<12> a = { 0x0f0 }, b = { 0x03c };
    bits<12> c = a & b, d = a | b, e = a ^ b, f = ~a;
    printf("%llx %llx %llx %llx\n", c.w, d.w, e.w, f.w);
    bits<12> g = a << 6, h = a >> 2, k = (a | b) << 1 >> 3;
    size_t n = 5;
    printf("%llx %llx %llx %llx\n", g.w, h.w, k.w, (a >> n).w);
    a &= b;
    printf("%llx", a.w);
    a |= d;
    a ^= b;
    a <<= 4;
    a >>= 1;
    printf(" %llx %d %d\n", a.w, a == d, a != d);
    b[0] = 1;
    b[5] = 0;
    b[11] = b[2];
    printf("%llx %d %d %d\n", b.w, b[0], b[1], b[11]);
    num<int> x = { 17 }, y = { 5 };
    num<int> z = x % y, w = -x, s = x + y, t = x + 3;
    printf("%d %d %d %d\n", z.v, w.v, s.v, t.v);
    x += y;
    x += 10;
    x -= y;
    x *= y;
    x /= t;
    x %= y;
    printf("%d %d %d %d %d\n", x.v, x == 1, x != 1, x == y, (-x + 1).v);
    num<double> p = { 1.5 };
    p += 2;
    p *= p;
    printf("%g %g\n", p.v, (-p).v);
    peek<8> q = { 0x05 };
    printf("%d %d %d\n", q[0], q[1], q[2]);
    return 0;
}
