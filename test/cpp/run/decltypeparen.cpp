// decltype((x)) of a variable is a reference ([dcl.type.decltype]/1.5), decltype(x) its declared type
#include <cstdio>
#include <type_traits>
int main() {
    int x = 1; const int c = 2; int &r = x;
    std::printf("%d %d %d %d\n", (int) std::is_same_v<decltype(x), int>, (int) std::is_same_v<decltype((x)), int &>, (int) std::is_same_v<decltype((c)), const int &>, (int) std::is_same_v<decltype(r), int &>);
    decltype((x)) y = x; y = 7;
    struct S { int m; } s{3};
    std::printf("%d %d %d\n", x, (int) std::is_same_v<decltype(s.m), int>, (int) std::is_same_v<decltype((s.m)), int &>);
    auto f = [&]() -> decltype(auto) { return (x); };
    f() = 9;
    std::printf("%d\n", x);
}
