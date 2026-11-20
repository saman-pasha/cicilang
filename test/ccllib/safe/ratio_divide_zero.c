/* <ratio.pl>: ratio_divide by a ratio of numerator 0 is refused, as std::ratio_divide's division by zero (1.6.4) */
#include <ratio.pl>
int main(void) {
    ratio_divide<1, 2, 0, 1> r;
    return (int)num(r);
}
