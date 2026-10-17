#include <stdarg.h>
#include "vec.h"
v4si h_add4(v4si a, v4si b) { return a + b; }
v4sf h_mul4(v4sf a, float k) { return a * k; }
v2df h_dbl(v2df a) { return a + a; }
v2si h_swap2(v2si a) { v2si r = {a[1], a[0]}; return r; }
v4hi h_neg4(v4hi a) { return -a; }
struct vs h_vs(struct vs s) { s.v += 1.0f; return s; }
struct vt h_vt(struct vt t) { t.a *= 2; t.b += 1; return t; }
int h_nine(v4si a, v4si b, v4si c, v4si d, v4si e, v4si f, v4si g, v4si h, v4si i) { return a[0] + b[1] + c[2] + d[3] + e[0] + f[1] + g[2] + h[3] + i[0] * 100; }
int h_sumv(int n, ...) { va_list ap; va_start(ap, n); int s = 0; for (int k = 0; k < n; k++) { v4si v = va_arg(ap, v4si); s += v[0] + v[3]; v2si w = va_arg(ap, v2si); s += w[1] * 10; } va_end(ap); return s; }
double via_helper(void) {
    v4si a = m_add4((v4si){1, 2, 3, 4}, (v4si){10, 20, 30, 40});
    v2si b = m_swap2((v2si){5, 6});
    struct vs d = m_vs((struct vs){{0.5f, 1.5f, 2.5f, 3.5f}});
    int e = m_sumv(2, (v4si){1, 0, 0, 2}, (v2si){0, 3}, (v4si){4, 0, 0, 5}, (v2si){0, 6});
    return a[0] + a[3] * 10 + b[0] * 100 + d.v[3] * 10000 + e * 100000;
}
