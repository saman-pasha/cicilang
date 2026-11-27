/* A STREAM CLOSED TWICE (1.6.32): fclose gives its memory back as free does -- it was built */
#include <stdio.h>
int main(void) { FILE *f = fopen("/dev/null", "r"); if (!f) return 1; fclose(f); fclose(f); return 0; }
