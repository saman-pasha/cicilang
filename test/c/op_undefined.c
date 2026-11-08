/* OPERATORS ON INSTANCES (0.266): the reader check k140 -- pt's type macro defines no pt_double_mul */
#include "run/topers.pl"
int main(void) {
    pt<double> a = { 1, 2 }, b = { 3, 4 };
    pt<double> c = a * b;
    return (int)c.x;
}
