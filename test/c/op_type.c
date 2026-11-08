/* OPERATORS ON INSTANCES (0.266): the reader check k140 -- == over a point takes a point on its right: 0 is none, and C
   would take it for a null pointer */
#include "run/topers.pl"
int main(void) {
    pt<double> a = { 1, 2 };
    return a == 0;
}
