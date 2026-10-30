/* 0.239: NDEBUG reaches the program's own header: its <assert.h> reads it there, as clang's does */
#include <stdio.h>
#define NDEBUG
#include "ndebuglocal.h"
int main(void) { printf("%d\n", checked(-1)); return 0; }
