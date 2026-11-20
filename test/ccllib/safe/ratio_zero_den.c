/* <ratio.pl>: a ratio's denominator is not zero, as std::ratio's static assertion refuses it (1.6.4) */
#include <ratio.pl>
int main(void) {
    ratio<1, 0> r;
    return (int)num(r);
}
