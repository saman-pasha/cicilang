#include <utility>
struct M { M() = default; M(M &&) = delete; };
int main() { M a; M b = std::move(a); (void)b; }
