// A file-scope `const' or `constexpr' integer with a constant initializer is usable in constant expressions
// ([expr.const]/4): an array's bound at file scope, in a block and in a class, `alignas', a bit-field's width, a template
// argument, `std::array', a case label, `if constexpr', an enumerator; one over a constexpr call; a namespace's; its value
// converted to its type, its address and its declared type the object's; two namespaces' of one name (0.195)
#include <array>
#include <cstdint>
#include <cstdio>
#include <type_traits>
const int K = 8;
constexpr int M = K * 2;
constexpr long L = 1L << 40;
enum Color { Red, Green, Blue };
constexpr Color C0 = Blue;
const unsigned U = 3u;
const unsigned char UC = 300;
namespace ns { constexpr int Q = 5; const int R = Q + 1; }
namespace a1 { const int Q2 = 2; int qa[Q2]; }
namespace b1 { const int Q2 = 7; int qb[Q2]; }
constexpr int twice(int x) { return 2 * x; }
constexpr int T = twice(M);
int arr[K];
alignas(K) char buf[3];
char wrapped[UC];
struct S { int a[M]; int bits : K; };
template <int N> struct V { static constexpr int value = N; };
int big[T];
int main() {
    int loc[K];
    std::array<int, ns::R> sa{};
    V<T> v;
    switch (3) { case U: std::printf("case\n"); break; default: break; }
    if constexpr (K > 4) std::printf("big\n");
    const int *p = &K;
    enum { E = K + 1 };
    std::printf("%zu %zu %d %zu %d %d %ld %d %zu %d %d %d\n", sizeof arr, sizeof loc, (int) ((std::uintptr_t) buf % K == 0),
                sizeof(S), V<K>::value, v.value, L, (int) C0, sa.size(), *p, ns::Q, E);
    std::printf("%zu %zu %d %d\n", sizeof big, sizeof wrapped, (int) std::is_same<decltype(K), const int>::value, (int) (p == &K));
    std::printf("%zu %zu %d %d\n", sizeof a1::qa, sizeof b1::qb, V<a1::Q2>::value, V<b1::Q2>::value);
    return 0;
}
