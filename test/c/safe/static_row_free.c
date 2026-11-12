/* a row of a static array freed (0.297): static storage, a borrow that nothing ends -- it was a pointer read out of a
   slot, which a free takes, and the run aborted in `free' */
#include <stdlib.h>
static unsigned char table[2][3] = { { 1, 2, 3 }, { 4, 5, 6 } };
int main(int argc, char **argv) { (void)argv; unsigned char *row = table[argc & 1]; free(row); return 0; }
