/* THE MACROS OF THE PROGRAM'S OWN HEADERS AND OF THEIR INCLUDER (0.298; the finding of a program over 0.284 and the
   forms beside it). A header's own `#define M 24' bounds its struct, where the raw read kept the name and the struct had
   no array; the file's CAP, WIDE, SQ and GREETING reach the header's bounds, its #ifdef, its #if, its function bodies
   and a header that it includes (ownm_inner.h names CAP, and the box header's K); a guarded header included twice adds
   nothing; LATE, defined after an #include, does not reach it; CAP at 4 bounds the next header; and a header that
   defines CAP again gives the file its 8 from there on. Each line is clang's */
#include <stdio.h>
#include <string.h>
#define CAP 16
#define WIDE 1
#define SQ(x) ((x) * (x))
#define GREETING "hello"
#include "ownm_box.h"
#include "ownm_box.h"
#include "ownm_late.h"
#define LATE 1
#undef CAP
#define CAP 4
#include "ownm_two.h"
#include "ownm_redef.h"
int main(void) {
    printf("%zu %zu %zu %zu\n", sizeof(box), sizeof(num), sizeof(big), sizeof(inner));
    printf("%d %zu %s %zu\n", area(4), sizeof(tab), greet(), glen());
    printf("%d %d %zu %zu %d\n", late, LATE, sizeof(two), sizeof(three), CAP);
    return 0;
}
