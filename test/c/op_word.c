/* OPERATORS ON INSTANCES (0.266): the reader check k140 -- << of a float calls tbuf_char_shl_float, which the macro does
   not define: a float is not promoted to double here, as no prototype converts it */
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "run/topers.pl"
int main(void) {
    tbuf<char> out = { 0 };
    out << 1.5f;
    return 0;
}
