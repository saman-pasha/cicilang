/* A FREED PLAIN POINTER HANDED TO A CALL (1.6.32): strlen reads memory given back -- it was built */
#include <stdlib.h>
#include <string.h>
int main(void) { char *p = malloc(8); if (!p) return 1; p[0] = 0; free(p); return (int) strlen(p); }
