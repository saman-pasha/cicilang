/* OPERATORS ON INSTANCES (0.266): the reader check k140 -- pt_double_eq takes its operands by address, and a + b is no
   lvalue */
#include "run/topers.pl"
int main(void) {
    pt<double> a = { 1, 2 }, b = { 3, 4 }, c = { 4, 6 };
    return (a + b) == c;
}
