/* NEW MEMORY THROWN AWAY (0.309): strdup's copy thrown away leaks its block, refused, dropped_memory */
#include <string.h>
int main(void) {
    strdup("abc");
    return 0;
}
