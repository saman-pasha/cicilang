/* OPERATORS ON INSTANCES, PART 2 (0.284): the reader check k153 -- peek<8> reads a bit by [] and writes none */
#include <stddef.h>
#include "run/topers2.pl"
int main(void) {
    peek<8> q = { 5 };
    q[1] = 1;
    return 0;
}
