/* AN OWN SLOT TAKES AN ANCHORED POINTER'S VALUE AS NEW MEMORY, AS BEFORE 0.299: getline gives new memory through the
   address of `line', and the own local that takes it and never frees it leaks it. The rule of 0.299 that takes such a
   value as no new memory holds in a plain slot, never in an own one */
#include <stdio.h>
#include <stdlib.h>
int main(void) {
    char *line = 0;
    size_t n = 0;
    FILE *f = fopen("/dev/null", "r");
    if (!f) return 2;
    long k = getline(&line, &n, f);
    fclose(f);
    own char *c = line;
    return k < 0 && c == 0;
}
