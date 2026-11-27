// the file's function beside a local of its name that is a pointer to a function (1.6.34; [basic.lookup.qual],
// [basic.lookup.unqual]/1): `::k(6)' and `::k' as a value name the file's -- they were the local's --, a class's static
// member and a namespace's stay theirs, the bare `k(6)' and the bare `ov(3)' beside the file's overloads are the
// local's -- the overloads were chosen --, and a lambda's capture of the local beside `::k'
#include <cstdio>
int k(int x) { return x + 100; }
static int dbl(int x) { return x * 2; }
static int ov(int x) { return x + 1; }
static double ov(double x) { return x + 0.5; }
struct S { static int k(int x) { return x + 7; } };
namespace n { int k(int x) { return x + 1000; } }
static int apply(int (*ov)(int), int v) { return ov(v) + ::ov(v); }
int main() {
    int (*k)(int) = dbl;
    int (*q)(int) = ::k;
    int (*ov)(int) = dbl;
    int a = S::k(6), b = q(1), c = ::ov(3), d = ov(3), e = ::k(6), f = k(6), g = n::k(6);
    auto l = [k](int v) { return ::k(v) + k(v); };
    std::printf("%d %d %d %d %d %d %d %d %d %d\n", a, b, c, d, e, f, g, l(2), (int) (::ov(1.0) * 2), apply(dbl, 4));
    return 0;
}
