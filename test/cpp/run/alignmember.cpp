// C++'s alignas before a member and a file-scope declaration is its specifier, the qualifier aligned(E) -- it was dropped
// as an attribute -- and a member's alignment folds in the class's words: a literal, a type, a value template parameter,
// a type template parameter; the class's own alignas over a template parameter; libc++'s std::array<T, 0> (0.194)
#include <array>
#include <cstddef>
#include <cstdio>
struct M { alignas(8) char c; };
struct M2 { char a; alignas(16) int b; char z; };
struct M3 { alignas(double) char d[3]; int f() const { return d[0]; } };
template <unsigned A> struct T { alignas(A) char c; };
template <class U> struct V { alignas(U) char c[sizeof(U)]; };
template <unsigned A> struct W { char x; alignas(A) int y; };
template <unsigned A> struct alignas(A) X { char c; };
alignas(32) char g[3];
alignas(16) static int gs;
char pad;
alignas(64) long gl = 7;
int main() {
    alignas(64) char l[5];
    alignas(double) char d[3];
    std::printf("%zu %zu %zu %zu %zu %zu\n", sizeof(M), alignof(M), sizeof(M2), alignof(M2), sizeof(M3), alignof(M3));
    std::printf("%zu %zu %zu %zu\n", offsetof(M2, b), offsetof(M2, z), sizeof(T<8>), alignof(T<4>));
    std::printf("%zu %zu %zu %zu %zu\n", sizeof(V<double>), alignof(V<double>), sizeof(W<16>), alignof(W<16>), offsetof(W<16>, y));
    std::printf("%zu %zu %zu %zu\n", sizeof(X<8>), alignof(X<8>), sizeof(X<32>), alignof(X<32>));
    std::printf("%d %d %d %d %d %ld\n", (int) ((unsigned long) g % 32), (int) ((unsigned long) &gs % 16), (int) ((unsigned long) &gl % 64),
                (int) ((unsigned long) l % 64), (int) ((unsigned long) d % 8), gl);
    std::printf("%zu %zu %zu %zu\n", sizeof(std::array<int, 0>), alignof(std::array<int, 0>), sizeof(std::array<double, 0>), alignof(std::array<double, 0>));
    T<8> t[2];
    std::printf("%d %d\n", (int) ((char *) &t[1] - (char *) &t[0]), (int) ((unsigned long) &t[1] % 8));
    return 0;
}
