/* OPERATORS ON INSTANCES, PART 2 (0.284): the reader check k153 -- += is its own function, which pt<double> has not */
#include "run/topers.pl"
int main(void) {
    pt<double> a = { 1, 2 }, b = { 3, 4 };
    a += b;
    return 0;
}
