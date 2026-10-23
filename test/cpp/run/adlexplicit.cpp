// C++20's ADL for a function template called with explicit template arguments (P0846), constinit, using enum,
// [[likely]], designated initializers, a lambda's template parameter list, consteval, aggregate with a base
#include <cstdio>
namespace ns { struct T { int v = 3; }; template <int N> int get(T t) { return t.v * N; } }
constinit int ci = 5;
enum class Col { red, green };
int pick(Col c) { using enum Col; switch (c) { case red: return 1; case green: return 2; } return 0; }
int likely(int x) { if (x > 0) [[likely]] return 1; else [[unlikely]] return 0; }
struct Pt { int x = 0, y = 0, z = 0; };
int main() {
    ns::T t;
    std::printf("%d %d %d %d\n", get<2>(t), ci, pick(Col::green), likely(4));
    Pt p{.x = 1, .z = 3};
    auto gl = []<class T>(T a, T b) { return a + b; };
    std::printf("%d %d %d %d\n", p.x, p.y, p.z, gl(2, 3));
}
