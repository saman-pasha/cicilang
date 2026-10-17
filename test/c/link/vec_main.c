#include <stdio.h>
#include <stdarg.h>
#include "vec.h"
/* the cicilang side: the functions the helper calls back */
v4si m_add4(v4si a, v4si b) { return a + b; }
v2si m_swap2(v2si a) { v2si r = {a[1], a[0]}; return r; }
struct vs m_vs(struct vs s) { s.v *= 2.0f; return s; }
int m_sumv(int n, ...) { va_list ap; va_start(ap, n); int s = 0; for (int k = 0; k < n; k++) { v4si v = va_arg(ap, v4si); s += v[0] + v[3]; v2si w = va_arg(ap, v2si); s += w[1] * 10; } va_end(ap); return s; }
int main(void) {
    v4si a = h_add4((v4si){1, 2, 3, 4}, (v4si){10, 20, 30, 40});
    v4sf f = h_mul4((v4sf){1.5f, 2.5f, 3.5f, 4.5f}, 2.0f);
    v2df d = h_dbl((v2df){1.25, -3.5});
    v2si s = h_swap2((v2si){7, 8});
    v4hi n = h_neg4((v4hi){1, -2, 3, -4});
    struct vs vs = h_vs((struct vs){{1, 2, 3, 4}});
    struct vt vt = h_vt((struct vt){{3, 4}, 9});
    printf("%d %d %d %d | %g %g %g %g | %g %g\n", a[0], a[1], a[2], a[3], f[0], f[1], f[2], f[3], d[0], d[1]);
    printf("%d %d | %d %d %d %d\n", s[0], s[1], n[0], n[1], n[2], n[3]);
    printf("%g %g %g %g | %d %d %d\n", vs.v[0], vs.v[1], vs.v[2], vs.v[3], vt.a[0], vt.a[1], vt.b);
    v4si k = {1, 2, 3, 4};
    printf("%d %d %.0f\n", h_nine(k, k, k, k, k, k, k, k, (v4si){7, 0, 0, 0}), h_sumv(2, (v4si){1, 0, 0, 2}, (v2si){0, 3}, (v4si){4, 0, 0, 5}, (v2si){0, 6}), via_helper());
    return 0;
}
