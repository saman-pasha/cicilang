/* OPERATORS ON INSTANCES, PART 2 (0.284): the reader check k153 -- the unary - is _neg, which pt<double> has not */
#include "run/topers.pl"
int main(void) {
    pt<double> a = { 1, 2 };
    pt<double> b = -a;
    return 0;
}
