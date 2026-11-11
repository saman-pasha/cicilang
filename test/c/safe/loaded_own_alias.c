/* A VALUE READ OUT OF AN OWN SLOT IS NOT A PLAIN SLOT'S (0.290): a read from a plain slot is no new memory, and goes
   into another plain slot; the pointer of a global owner, read into a local, is still the check's to place, so that no
   plain slot keeps it past the owner's free */
#include <stdlib.h>
static own char *gbuf;
static char *gc;
int main(void) {
    gbuf = malloc(4);
    char *q = gbuf;
    gc = q;
    free(gbuf);
    return gc != 0;
}
