/* THE PROGRAM'S OWN HEADERS OVER A TYPE MACRO'S INSTANCE (0.293; the finding of a program over 0.284): a header's
   static inline functions that take a vector<pt> member's [] and call its functions by name, beside the header's own
   macros and C17's bool (hdrvec.h); a header that includes that header (hdrvec2.h); and one with no #include, over
   the struct that the headers before it declare (hdrvec3.h). Each function was lowered from its header read alone,
   where no instance is -- `not lowered yet: not_a_pointer', `no_member(pts)', or the vector taken by value -- and in
   C++ too for the two later headers. clang++'s build of its twin over std::vector prints what this file prints */
#include <stdio.h>
#include "hdrvec2.h"
#include "hdrvec3.h"
int main(void) {
    poly p = {0};
    defer(p) { vector_pt_drop(&p.pts); }
    int e = no_pts(&p);
    add_pt(&p, 3, 4);
    add_pt(&p, 5, 6);
    add_pt(&p, 7, 8);
    printf("%d %d %d %d %d %d\n", e, no_pts(&p), first_x2(&p), last_y(&p), count_of(&p), sum_x(&p));
    return 0;
}
