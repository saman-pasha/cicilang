// scopedtypes.cpp (1.6.2): GNU's __typeof__ of a name that two blocks declare with two types is each block's, as
// decltype, a block's typedef and a block's alias already were, and a block's typedef of a typeof is taken where the
// typedef stands
#include <cstdio>
int main() {
    { int b = 1; __typeof__(b) u = b; decltype(b) v = b; std::printf("%d %d ", u, v); }
    { double b = 2.5; __typeof__(b) u = b; decltype(b) v = b; std::printf("%g %g ", u, v); }
    { long b = 5000000000L; __typeof__(b) arr[2] = { b, b }; __typeof__(b) *p = &arr[1]; std::printf("%ld %zu ", *p, sizeof(__typeof__(b))); }
    { typedef int T; T a = 1; std::printf("%d ", a); }
    { typedef double T; T a = 2.5; std::printf("%g ", a); }
    { using U = int; U a = 3; std::printf("%d ", a); }
    { using U = double; U a = 3.5; std::printf("%g\n", a); }
    return 0;
}
