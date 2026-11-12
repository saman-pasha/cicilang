/* THE PROGRAM'S OWN HEADERS OVER A TYPE MACRO'S INSTANCE, WITH NO MACRO FILE OF THEIR OWN (0.298; the findings 22 and
   23 of a program over 0.284 and the forms beside them): a struct with a vector<int> member in a header that includes
   no <vector.pl>, under a file that includes it first, through a header that includes it (hdrinst_shelf.h over
   hdrinst_bag.h); such a struct and the prototypes of functions that the file defines after main (hdrinst_st.h); a
   typedef of the instance's type and a prototype over it (hdrinst_ivec.h); and a guarded header, included twice, whose
   struct makes the first instance of vector<double>, with a macro of its own over it (hdrinst_pts.h). Each header's
   read stopped at its first line, and the unit met `not lowered yet: typedef(bag)' (in C++,
   `template_without_body(vector)') */
#include <stdio.h>
#include <vector.pl>
#include "hdrinst_shelf.h"
#include "hdrinst_st.h"
#include "hdrinst_ivec.h"
#include "hdrinst_pts.h"
#include "hdrinst_pts.h"
int total(ivec *v) { int s = 0; for (size_t i = 0; i < len(*v); i++) s += at(*v, i); return s; }
int main(void) {
    shelf sh = {0};
    defer(sh) { vector_int_drop(&sh.b.items); }
    push_back(sh.b.items, 5); push_back(sh.b.items, 6); sh.n = 1;
    st s = {0};
    defer(s) { vector_int_drop(&s.v); }
    push_back(s.v, 4); s.n = 2;
    ivec v = {0};
    push_back(v, 3); push_back(v, 4);
    pts p = {0};
    defer(p) { vector_double_drop(&p.xs); }
    push_back(p.xs, 2.5); push_back(p.xs, 1.0);
    printf("%d %d %d %d %d %.1f\n", (int)len(sh.b.items) * 10 + at(sh.b.items, 1) + sh.n, count(&s), twice(21), total(&v), (int)len(p.xs), FIRST(&p));
    return 0;
}
int count(const st *s) { return (int)vector_int_len(&s->v) + s->n; }
int twice(int x) { return 2 * x; }
