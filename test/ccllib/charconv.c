/* ccllib phase 2 (CCLLIB.md): <charconv.pl>, built by cicilang as C and by cicilang++ as C++, and compared with
   charconv.cpp over std::charconv, which clang++ builds. The three print charconv.expect. */
#include <stdio.h>
#include <string.h>
#include <charconv.pl>

int main(void) {
    char buf[64];
    to_chars_result r;
    r = to_chars(buf, buf + 64, 42);
    buf[r.pos] = 0;
    printf("int %s %d\n", buf, r.ec == 0);
    r = to_chars(buf, buf + 64, -255);
    buf[r.pos] = 0;
    printf("neg %s\n", buf);
    r = to_chars(buf, buf + 64, 255, 16);
    buf[r.pos] = 0;
    printf("hex %s\n", buf);
    r = to_chars(buf, buf + 64, 255, 2);
    buf[r.pos] = 0;
    printf("bin %s\n", buf);
    r = to_chars(buf, buf + 64, 3.5);
    buf[r.pos] = 0;
    printf("dbl %s\n", buf);
    r = to_chars(buf, buf + 64, 3.5, chars_fixed);
    buf[r.pos] = 0;
    printf("fixed %s\n", buf);
    r = to_chars(buf, buf + 64, 3.5, chars_scientific);
    buf[r.pos] = 0;
    printf("sci %s\n", buf);
    r = to_chars(buf, buf + 64, 100.0, chars_hex);
    buf[r.pos] = 0;
    printf("chex %s\n", buf);
    r = to_chars(buf, buf + 2, 12345);
    printf("small %d\n", r.ec == ccllib_errc_value_too_large);

    int v = 0;
    from_chars_result f = from_chars("42x", "42x" + 3, v);
    printf("from %d %d %d\n", (int)f.pos, f.ec == 0, v);
    f = from_chars("x", "x" + 1, v);
    printf("bad %d %d\n", (int)f.pos, f.ec == ccllib_errc_invalid_argument);
    f = from_chars("999999999999999999999", "999999999999999999999" + 21, v);
    printf("range %d %d\n", (int)f.pos, f.ec == ccllib_errc_result_out_of_range);
    f = from_chars("ff", "ff" + 2, v, 16);
    printf("hexin %d %d %d\n", (int)f.pos, f.ec == 0, v);

    double d = 0;
    f = from_chars("3.5x", "3.5x" + 4, d);
    printf("dblin %d %d %g\n", (int)f.pos, f.ec == 0, d);
    f = from_chars(" 3.5", " 3.5" + 4, d);
    printf("space %d %d\n", (int)f.pos, f.ec == ccllib_errc_invalid_argument);
    f = from_chars("3.5e2x", "3.5e2x" + 6, d);
    printf("exp %d %d %g\n", (int)f.pos, f.ec == 0, d);
    return 0;
}
