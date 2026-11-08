/* A NULL OWN FIELD THAT A CALL MAY FILL IS LIVE AFTER IT (0.267): grow takes the struct by a plain pointer and may put a
   buffer where the field was null -- realloc(NULL, n) allocates -- so v owns one after the call, and the return leaks
   it; it was taken, and valgrind found the 16 bytes lost */
#include <stdlib.h>
typedef struct { size_t len; own int *data; } buf;
void grow(buf *b) { b->len = b->len ? 2 * b->len : 4; b->data = realloc(b->data, b->len * sizeof(int)); }
int main(void) {
    buf v = { 0, NULL };
    grow(&v);
    return 0;
}
