// C++17's nested namespace definition and C++20's `inline' inside one, a namespace alias, and a friend class
// template named through its namespace -- the forms libc++ 18's <ranges> is written in.
#include <cstdio>
namespace outer::inner { int f() { return 1; } }
namespace outer::inline v2 { int g() { return 2; } }
namespace oi = outer::inner;
namespace outer { template <class> struct traits { static int get() { return 4; } }; }
struct Holder { template <class> friend struct outer::traits; int v = 3; };
namespace outer::inner { int h() { return f() + 10; } }
int main() {
    Holder x;
    std::printf("%d %d %d %d %d %d\n", outer::inner::f(), oi::f(), outer::g(), x.v, outer::traits<int>::get(), oi::h());
    return 0;
}
