/* OPERATORS ON INSTANCES (0.266): the reader check k140 -- >> reads into its right operand, so 5 is refused */
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "run/topers.pl"
int main(void) {
    tbuf<char> in = { 0 };
    in << "5";
    in >> 5;
    return 0;
}
