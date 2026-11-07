#include <utility>
struct M { M() = default; M(const M &) = default; M(M &&) = delete; };
struct S { M m; S() = default; S(S &&) = default; };
int main() { S a; S b = std::move(a); (void)b; }
