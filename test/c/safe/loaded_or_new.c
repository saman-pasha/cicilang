/* A POINTER READ OUT OF A SLOT IS NO NEW MEMORY, BUT A CONDITIONAL WITH NEW MEMORY ON ONE SIDE IS (0.290): the block
   that malloc gives on one path is still to be given back */
#include <stdlib.h>
static char *tab[2];
int main(int argc, char **argv) {
    (void)argv;
    char *s = argc > 1 ? tab[0] : (char *)malloc(4);
    return s == 0;
}
