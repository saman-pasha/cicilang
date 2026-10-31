// An enumerator's value may name another enum's enumerator, a header's too, and a file-scope constant, in a block's enum
// too, and an array's bound such an enumerator: the passes folded the unit's enums with their own enumerators alone (0.195)
#include <cstdio>
#include <unistd.h>
enum A { X = 5 };
enum B { Y = X + 1, Z = sizeof(int) * X };
enum { SC = _SC_PAGESIZE + 1 };
const int K = 3;
enum C2 { W = K * 4, W2 };
int arr[Y];
int main() {
    enum D { V = Y * 2 };
    std::printf("%d %d %d %d %d %zu\n", (int) Y, (int) Z, (int) W, (int) W2, (int) V, sizeof arr);
    std::printf("%d\n", (int) (SC == _SC_PAGESIZE + 1));   // the C library's value: 30 on glibc, 29 on macOS (0.250)
    return 0;
}
