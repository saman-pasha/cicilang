// attributes with arguments and on odd places: [[nodiscard("why")]], [[deprecated("x")]], a nodiscard constructor,
// [[no_unique_address]] (done), alignas on a struct, alignof, a label attribute, an enumerator's attribute
#include <cstdio>
struct [[nodiscard("keep")]] R { int v; };
R mk() { return {3}; }
struct S { [[nodiscard]] S(int x) : v(x) {} int v; };
[[deprecated("old")]] int old() { return 1; }
enum E { A [[maybe_unused]] = 1, B };
struct alignas(32) Al { char c; };
int main() {
    R r = mk(); S s(2);
    std::printf("%d %d %d %d %zu %zu\n", r.v, s.v, B, (int) A, alignof(Al), sizeof(Al));
}
