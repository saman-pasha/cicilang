// OPERATORS ON INSTANCES IN C++ (0.270; CCLLIB.md's phase 0.10): an instance's operator is the call of the function its
// type macro defines for it, an operand of a reference type the object it refers to, and C++'s own operator where the
// macro defines none (`a * 2.0', the program's operator*) or where the instance is on the right alone (`2.0 * b').
// Without a library header: the names that topers.pl's C text calls are declared by hand
typedef unsigned long size_t;
extern "C" {
void *realloc(void *, size_t) noexcept;
void free(void *) noexcept;
size_t strlen(const char *) noexcept;
void *memcpy(void *, const void *, size_t) noexcept;
int snprintf(char *, size_t, const char *, ...) noexcept;
int printf(const char *, ...);
}
#include "../../c/run/topers.pl"
pt<double> operator*(pt<double> a, double k) { pt<double> r = { a.x * k, a.y * k }; return r; }
pt<double> operator*(double k, pt<double> a) { return a * k; }
int same(const pt<double> &p, const pt<double> &q) { return p == q; }
int main() {
    pt<double> a = { 1, 2 }, b = { 3, 4 };
    pt<double> c = a + b;
    pt<double> d = a * 2.0;
    pt<double> e = 2.0 * b;
    ring<int, 4> r = { 3 };
    r[1] = 7;
    printf("%g %g %g %g %g %g %d %d %d %d\n", c.x, c.y, d.x, d.y, e.x, e.y, same(a, b), same(a, a), r[1], r.a[0]);
    return 0;
}
