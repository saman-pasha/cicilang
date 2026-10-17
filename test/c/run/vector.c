/* GCC's vector_size and clang's ext_vector_type: lane arithmetic, masks, lanes, the vector builtins, the ABI */
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
typedef int v4si __attribute__((vector_size(16)));
typedef unsigned v4su __attribute__((vector_size(16)));
typedef float v4sf __attribute__((vector_size(16)));
typedef double v2df __attribute__((vector_size(16)));
typedef int v2si __attribute__((vector_size(8)));
typedef short v4hi __attribute__((vector_size(8)));
typedef unsigned char v4qu __attribute__((vector_size(4)));
typedef long long v2di __attribute__((vector_size(16)));
typedef int __attribute__((ext_vector_type(4))) e4;
typedef _Bool __attribute__((ext_vector_type(4))) b4;
typedef _Bool __attribute__((ext_vector_type(16))) b16;
struct pack { v4sf v; int tag; };
v4si g = {1, 2, 3, 4};
v4sf gf = {0.5f, 1.5f};
static void show(const char *s, v4si v) { printf("%s %d %d %d %d\n", s, v[0], v[1], v[2], v[3]); }
static void showf(const char *s, v4sf v) { printf("%s %g %g %g %g\n", s, v[0], v[1], v[2], v[3]); }
static v4si twice(v4si v) { return v + v; }
static v2si swap2(v2si v) { v2si r = {v[1], v[0]}; return r; }
static v4hi neg4(v4hi v) { return -v; }
static v4qu inc4(v4qu v) { return v + 1; }
static struct pack scale(struct pack p, float k) { p.v *= k; p.tag++; return p; }
static int sumv(int n, ...) { va_list ap; va_start(ap, n); int s = 0; for (int i = 0; i < n; i++) { v4si v = va_arg(ap, v4si); s += v[0] + v[3]; } va_end(ap); return s; }
static int sumw(int n, ...) { va_list ap; va_start(ap, n); int s = 0; for (int i = 0; i < n; i++) { v2si v = va_arg(ap, v2si); s += v[0] * 10 + v[1]; } va_end(ap); return s; }
int main(void) {
    v4si a = {1, -2, 3, -4}, b = {5, 6, 7, 8};
    show("add", a + b); show("sub", a - b); show("mul", a * b); show("div", b / a); show("mod", b % 3);
    show("and", a & b); show("or", a | b); show("xor", a ^ b); show("shl", a << 2); show("shr", a >> 1); show("shrv", b >> (v4si){0, 1, 2, 3});
    show("neg", -a); show("not", ~a); show("splat", a + 10); show("splat2", 100 - b);
    show("lt", a < b); show("eq", a == (v4si){1, 2, 3, -4}); show("ge", a >= 0);
    v4su u = {1, 2, 0x80000000u, 0xffffffffu};
    v4su us = u >> 1; printf("ushr %u %u %u %u\n", us[0], us[1], us[2], us[3]);
    v4si um = u > 2u; show("ugt", um);
    a[2] = 30; a[0] += 100; show("lane", a); printf("read %d\n", a[1] + b[3]);
    show("glob", g); g = twice(g); show("twice", g);
    v4sf f = {1.0f, 2.5f, -3.0f, 4.0f};
    showf("fmul", f * 2.0f); showf("fdiv", f / (v4sf){2, 2, 4, 8}); showf("fneg", -f); showf("gf", gf);
    show("fgt", f > 1.5f);
    v4sf bits = (v4sf) (v4si){0x3f800000, 0x40000000, 0, 0}; showf("cast", bits);
    v2df d = {1.25, -2.5}; v2df d2 = d * d; printf("v2df %g %g %zu\n", d2[0], d2[1], sizeof d2);
    v2si w = {7, 9}; w = swap2(w); printf("swap2 %d %d\n", w[0], w[1]);
    v4hi h = {1, -2, 300, -400}; h = neg4(h); printf("v4hi %d %d %d %d\n", h[0], h[1], h[2], h[3]);
    v4qu q = {0, 1, 254, 255}; q = inc4(q); printf("v4qu %u %u %u %u\n", q[0], q[1], q[2], q[3]);
    struct pack p = {{1, 2, 3, 4}, 7}; p = scale(p, 0.5f); showf("pack", p.v); printf("tag %d\n", p.tag);
    printf("va %d %d\n", sumv(2, (v4si){1, 2, 3, 4}, (v4si){10, 20, 30, 40}), sumw(3, (v2si){1, 2}, (v2si){3, 4}, (v2si){5, 6}));
    e4 e = {1, 0, 3, 0};
    b4 m = __builtin_convertvector(e, b4);
    printf("bool %d %d %d %d all %d any %d\n", m[0], m[1], m[2], m[3], __builtin_reduce_and(m), __builtin_reduce_or(m));
    e4 back = __builtin_convertvector(m, e4); printf("back %d %d %d %d\n", back[0], back[1], back[2], back[3]);
    v4sf cf = __builtin_convertvector(b, v4sf); showf("cvt", cf);
    v4si ci = __builtin_convertvector((v4sf){1.9f, -1.9f, 2.5f, 100.0f}, v4si); show("cvti", ci);
    show("shuf", __builtin_shufflevector(a, b, 0, 4, 1, 5));
    v2si lo = __builtin_shufflevector(b, b, 3, 2); printf("shuf2 %d %d\n", lo[0], lo[1]);
    printf("reduce %d %d %d %d %d %d\n", __builtin_reduce_add(e), __builtin_reduce_mul((e4){1, 2, 3, 4}), __builtin_reduce_max(a), __builtin_reduce_min(a), __builtin_reduce_xor(b), __builtin_reduce_and(b));
    printf("reducef %g %g\n", __builtin_reduce_max(f), __builtin_reduce_min(f));
    typedef signed char v16qi __attribute__((vector_size(16)));
    v16qi qs = {0, 1, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1};
    b16 big = __builtin_convertvector(qs, b16); unsigned short mask; memcpy(&mask, &big, sizeof mask);
    printf("b16 %04x %d %d\n", mask, __builtin_reduce_or(big), __builtin_reduce_and(big));
    printf("sizes %zu %zu %zu %zu %zu %zu %zu\n", sizeof(v4si), sizeof(v2si), sizeof(v4qu), sizeof(b4), sizeof(b16), _Alignof(v4si), sizeof(struct pack));
    return 0;
}
