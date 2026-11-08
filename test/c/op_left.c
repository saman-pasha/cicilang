/* OPERATORS ON INSTANCES (0.266): the reader check k140 -- the left operand decides, and 1 is no point */
#include "run/topers.pl"
int main(void) {
    pt<double> a = { 1, 2 };
    pt<double> c = 1 + a;
    return (int)c.x;
}
