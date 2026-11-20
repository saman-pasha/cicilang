/* <ratio.pl>: a ratio_add whose sum is past intmax_t is refused, as libc++'s __ll_add refuses it (1.6.4) */
#include <ratio.pl>
int main(void) {
    ratio_add<9223372036854775807, 2, 9223372036854775805, 2> r;
    return (int)num(r);
}
