/* <ratio.pl>: a ratio_multiply whose product is past intmax_t is refused, as libc++'s __ll_mul refuses it (1.6.4) */
#include <ratio.pl>
int main(void) {
    ratio_multiply<4611686018427387904, 1, 4, 1> r;
    return (int)num(r);
}
