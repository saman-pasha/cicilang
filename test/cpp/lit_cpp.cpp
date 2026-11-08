// list and map literals in C++ (0.269): `[' begins a literal where the `]' that closes it is followed by none of what
// follows a lambda's introducer, so the lambdas beside them read as before, and an attribute's `[[' is no array's
// declarator, whose bound the attribute's inner brackets would be. No library header: the names that the instances'
// C text calls are declared here
typedef unsigned long size_t;
extern "C" void *realloc(void *, size_t) noexcept;
extern "C" void free(void *) noexcept;
#include "../c/run/tvector.pl"
#include "../c/run/literal.pl"
struct S { int x = 0; int *data() [[clang::lifetimebound]] { return &x; } };
int main() {
    S s;
    v := [int; 5, 3, 9];
    vector<double> w = [1, 2.5];
    auto f = [](int a) { return a + 1; };
    auto g = [&v] { return len(v); };
    vector<int> e = [];
    m := [int:double; 5: 1.25];
    return f(1) + (int) g() + (int) len(w) + (int) len(e) + (int) size(m) + *s.data();
}
