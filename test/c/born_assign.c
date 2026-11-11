/* AN INSTANCE'S BIRTH (0.285): the reader check k157 -- a = 5 would make a pt<double> of a number, as = 5 would */
#include "run/topers.pl"
int main(void) {
    pt<double> a = { 1, 2 };
    a = 5;
    return 0;
}
