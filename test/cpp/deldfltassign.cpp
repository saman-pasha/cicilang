#include <utility>
struct M { M() = default; M &operator=(M &&) = delete; M &operator=(const M &) = default; };
struct S { M m; S &operator=(S &&) = default; };
int main() { S a, b; a = std::move(b); }
