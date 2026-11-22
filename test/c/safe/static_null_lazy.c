/* static_null_lazy.c (1.6.20): a static local declared null and given new memory once -- static storage that holds new
   memory with no owner behind it: refused, as before 1.6.20; a static local declared null is no key of its frame */
#include <stdlib.h>
static char *buffer(void) {
    static char *buf = NULL;
    if (!buf) buf = malloc(64);
    return buf;
}
int main(void) { return buffer() == buffer() ? 0 : 1; }
