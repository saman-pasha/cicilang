/* A FREED PLAIN POINTER'S ADDRESS HANDED TO GETLINE (1.6.32): getline reads *lineptr and reallocs it, memory given back
   -- the pointer stays freed, and a null is given it first */
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
int main(void) { char *line = malloc(4); size_t n = 0; free(line); FILE *f = fopen("/dev/null", "r"); if (!f) return 1; long k = getline(&line, &n, f); fclose(f); free(line); return (int) k + 1; }
