/* OPERATORS ON INSTANCES (0.266; CCLLIB.md's phase 0.9): the reader writes an instance's operator as the call of the
   function its type macro names for it -- arithmetic and comparison over a point, [] over a ring and over a
   dictionary, << >> and + over text. A place that [] answers is a borrow of the object: kept, it is read before the
   next call that may replace the dictionary's buffers */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "topers.pl"
int main(void) {
    pt<double> a = { 1, 2 }, b = { 3, 0.5 };
    pt<double> c = a + b;
    pt<double> d = c - a;
    pt<double> e = a + b + c;
    printf("%g %g %g %g %g %g\n", c.x, c.y, d.x, d.y, e.x, e.y);
    printf("%d %d %d %d %d %d %d %d\n", a == b, d == b, a != b, a < b, b < a, a > b, a <= a, b >= a);
    ring<int, 4> r = { 2 };
    for (int i = 0; i < 4; i++) r[i] = i * 10;
    r[1] += 5;
    int *q = &r[2];
    *q = -1;
    printf("%d %d %d %d\n", r[0], r[1], r.a[0], r.a[3]);
    tbuf<char> out = { 0 };
    out << "a = " << 3 << ", b = " << 2.5 << "\n";
    out << "d == b: " << (d == b);
    printf("%s\n", tbuf_char_str(&out));
    tbuf<char> in = { 0 };
    in << "12 34";
    int p, n;
    in >> p >> n;
    printf("%d\n", p + n);
    tbuf<char> s = { 0 }, t = { 0 };
    s << "ab";
    t << "cd";
    tbuf<char> st = s + t;
    printf("%s %zu\n", tbuf_char_str(&st), st.len);
    dict<int, int> m = { 0 };
    m[3] = 30;
    m[7] += 2;
    m[3]++;
    int *slot = &m[3];
    *slot *= 2;
    int z = m[5];
    printf("%zu %d %d %d\n", dict_int_int_size(&m), m[3], m[7], z);
    return 0;
}
