// the twin of charconv.c over std::charconv (phase 2): clang++ builds it over libc++ and it prints charconv.expect
#include <charconv>
#include <cstdio>
#include <cstring>
#include <system_error>

int main() {
    char buf[64];
    auto r = std::to_chars(buf, buf + 64, 42);
    *r.ptr = 0;
    std::printf("int %s %d\n", buf, (int)(r.ec == std::errc()));
    r = std::to_chars(buf, buf + 64, -255);
    *r.ptr = 0;
    std::printf("neg %s\n", buf);
    r = std::to_chars(buf, buf + 64, 255, 16);
    *r.ptr = 0;
    std::printf("hex %s\n", buf);
    r = std::to_chars(buf, buf + 64, 255, 2);
    *r.ptr = 0;
    std::printf("bin %s\n", buf);
    r = std::to_chars(buf, buf + 64, 3.5);
    *r.ptr = 0;
    std::printf("dbl %s\n", buf);
    r = std::to_chars(buf, buf + 64, 3.5, std::chars_format::fixed);
    *r.ptr = 0;
    std::printf("fixed %s\n", buf);
    r = std::to_chars(buf, buf + 64, 3.5, std::chars_format::scientific);
    *r.ptr = 0;
    std::printf("sci %s\n", buf);
    r = std::to_chars(buf, buf + 64, 100.0, std::chars_format::hex);
    *r.ptr = 0;
    std::printf("chex %s\n", buf);
    r = std::to_chars(buf, buf + 2, 12345);
    std::printf("small %d\n", (int)(r.ec == std::errc::value_too_large));

    int v = 0;
    auto f = std::from_chars("42x", "42x" + 3, v);
    std::printf("from %d %d %d\n", (int)(f.ptr - "42x"), (int)(f.ec == std::errc()), v);
    f = std::from_chars("x", "x" + 1, v);
    std::printf("bad %d %d\n", (int)(f.ptr - "x"), (int)(f.ec == std::errc::invalid_argument));
    f = std::from_chars("999999999999999999999", "999999999999999999999" + 21, v);
    std::printf("range %d %d\n", (int)(f.ptr - "999999999999999999999"), (int)(f.ec == std::errc::result_out_of_range));
    f = std::from_chars("ff", "ff" + 2, v, 16);
    std::printf("hexin %d %d %d\n", (int)(f.ptr - "ff"), (int)(f.ec == std::errc()), v);

    double d = 0;
    f = std::from_chars("3.5x", "3.5x" + 4, d);
    std::printf("dblin %d %d %g\n", (int)(f.ptr - "3.5x"), (int)(f.ec == std::errc()), d);
    f = std::from_chars(" 3.5", " 3.5" + 4, d);
    std::printf("space %d %d\n", (int)(f.ptr - " 3.5"), (int)(f.ec == std::errc::invalid_argument));
    f = std::from_chars("3.5e2x", "3.5e2x" + 6, d);
    std::printf("exp %d %d %g\n", (int)(f.ptr - "3.5e2x"), (int)(f.ec == std::errc()), d);
    return 0;
}
