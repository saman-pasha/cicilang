/* <charconv.pl>: a value out of range leaves the object as it was and gives result_out_of_range, as C++17's
   [charconv.from.chars]/1 says, a denormal in range (1.6.4). libc++ 22 writes an infinity or a zero, so the program
   has no twin. Built as C and as C++. */
#include <stdio.h>
#include <charconv.pl>
int main(void) {
    double x = 7;
    float y = 7;
    long double z = 7;
    from_chars_result f;
    f = from_chars("1e999", "1e999" + 5, x);
    printf("%d %d %g\n", (int)f.pos, f.ec == ccllib_errc_result_out_of_range, x);
    f = from_chars("-1e999", "-1e999" + 6, x);
    printf("%d %d %g\n", (int)f.pos, f.ec == ccllib_errc_result_out_of_range, x);
    f = from_chars("1e-999", "1e-999" + 6, x);
    printf("%d %d %g\n", (int)f.pos, f.ec == ccllib_errc_result_out_of_range, x);
    f = from_chars("1e39", "1e39" + 4, y);
    printf("%d %d %g\n", (int)f.pos, f.ec == ccllib_errc_result_out_of_range, (double)y);
    f = from_chars("1e-46", "1e-46" + 5, y);
    printf("%d %d %g\n", (int)f.pos, f.ec == ccllib_errc_result_out_of_range, (double)y);
    f = from_chars("1e99999", "1e99999" + 7, z);
    printf("%d %d %g\n", (int)f.pos, f.ec == ccllib_errc_result_out_of_range, (double)z);
    f = from_chars("1e400", "1e400" + 5, z);
    printf("%d %d %g\n", (int)f.pos, f.ec == 0, (double)(z / 1e300L));
    f = from_chars("1e-310", "1e-310" + 6, x);
    printf("%d %d %g\n", (int)f.pos, f.ec == 0, x);
    f = from_chars("1e-40", "1e-40" + 5, y);
    printf("%d %d %g\n", (int)f.pos, f.ec == 0, (double)y);
    return 0;
}
