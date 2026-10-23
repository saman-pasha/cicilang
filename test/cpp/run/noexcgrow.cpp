// -fno-exceptions (0.193): libc++'s no-exceptions configuration, as this compiler built it from 0.50 to 0.192 -- a vector
// grows by moving an element whose move constructor may throw, where the exceptions configuration copies it
// (nothrowtraits.cpp); the traits still answer the declarations
#include <cstdio>
#include <type_traits>
#include <vector>

struct T {
    int v;
    T(int x) : v(x) {}
    T(const T &o) : v(o.v) { std::printf("copy T\n"); }
    T(T &&o) : v(o.v) { std::printf("move T\n"); }
};

int main() {
    std::vector<T> vt;
    vt.reserve(1);
    vt.emplace_back(1);
    vt.emplace_back(2);
    std::printf("%d %d\n", (int) std::is_nothrow_move_constructible_v<T>, vt[0].v + vt[1].v);
    return 0;
}
