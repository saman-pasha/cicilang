/* THE PROGRAM'S OWN HEADER'S DIRECTIVES RUN IN THE FILE'S RUN (0.298): an #undef of the file's macro in its own header,
   at any depth (CAP, BIG, NARROW); the file's #undef of a name that its own header defines after it (LEN); a guarded
   header that includes one whose text the run passed, after the file defined its macro again (X); a guarded header
   included again after another defined its macro again (Y); a macro of an own header that a library header after it
   defines again (MIN). Y came out as the guarded header's table had it, read apart, and X so in this step's first
   form; CAP, BIG and NARROW stayed, and LEN was undeclared; MIN was as it is */
#include <stdio.h>
#define CAP 16
#define BIG(a, b) ((a) > (b) ? (a) : (b))
#define WIDE 1
#define NARROW 5
#include "ownu_a.h"
#include "ownu_w.h"
#include "ownu_w.h"
#undef LEN
#include "ownu_len.h"
#include "ownu_q.h"
#undef X
#define X 5
#include "ownu_p.h"
#include "ownu_y1.h"
#include "ownu_y2.h"
#include "ownu_y1.h"
#include "ownu_min.h"
#include <sys/param.h>
int ownu_p(void) { return 0; }
static char buf[LEN];
int main(void) {
#ifdef CAP
    printf("CAP %d\n", CAP);
#else
    printf("no CAP\n");
#endif
#ifdef NARROW
    printf("NARROW %d\n", NARROW);
#else
    printf("no NARROW\n");
#endif
    printf("%d %d %d %d %d %d %d\n", BIG(3, 7), WIDE, (int)sizeof buf, X, Y, MIN(3, 4), ownu_p());
    return 0;
}
