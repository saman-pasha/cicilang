// two namespaces declaring one name: a class, a function and an object; the deeper namespace's own bare uses;
// a customization point object (a namespace-scope object called through its operator()); an inline namespace
#include <cstdio>
struct Fn { int operator()(int x) const { return x * 2; } };
int cpo(int x) { return x + 100; }
struct Box { int v; };
namespace R {
    struct Box { int a; int b; };
    inline constexpr Fn cpo{};
    int size(Box b) { return b.a + b.b; }
    int use() { Box b{1, 2}; return size(b) + cpo(5); }
    inline namespace v2 { int version() { return 2; } }
}
int size(Box b) { return b.v * 10; }
template <class T> int twice(T v) { return R::cpo(v) + cpo(v); }
int main() {
    Box x{4};
    R::Box y{3, 4};
    printf("%d %d %d %d %d %d %d\n", R::cpo(3), cpo(3), twice(1), size(x), R::size(y), R::use(), R::version());
    return 0;
}
