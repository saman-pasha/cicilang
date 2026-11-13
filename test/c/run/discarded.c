/* WHAT STAYS ALLOWED THROWN AWAY (0.309): a call whose pointer is its argument's, the library's storage or the
   program's static storage is no new memory, and an expression statement throws it away -- strcpy, memcpy, memset,
   strcat, strtok, fgets and a function of static storage -- where new memory thrown away is refused (test/c/safe's
   dropped_*.c). Built as C and, by the C++ gate, as C++ */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static int g[4];
static int *at(int i) { return &g[i]; }
int main(void) {
    char d[16], s[16] = "a b c";
    strcpy(d, "xy");
    memcpy(d + 2, "z", 2);
    memset(s + 6, 0, 2);
    strcat(d, "!");
    strtok(s, " ");
    at(1);
    FILE *f = fopen("/dev/null", "r");
    if (f) {
        char buf[8];
        fgets(buf, sizeof buf, f);
        fclose(f);
    }
    printf("%s %s\n", d, s);
    return 0;
}
