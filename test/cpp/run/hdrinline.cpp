// an inline function the program's own header defines is emitted with the program, not only declared
#include "hunit.h"
#include <cstdio>
int main() { printf("%d %d\n", twelve(), SQ(twelve())); return 0; }
