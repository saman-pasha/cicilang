// An object declared `auto' at namespace scope and as a static member takes its initializer's type, and a
// call of it goes to its class's operator() -- how libc++'s range policy reaches its customization points.
#include <cstdio>
namespace ns {
namespace cpo { struct fn { int operator()(int x) const { return x * 2; } }; }
inline namespace c { inline constexpr auto twice = cpo::fn{}; }
}
template <class P> struct Ops;
struct Pol {};
template <> struct Ops<Pol> { static constexpr auto tw = ns::twice; };
struct Plain { static constexpr auto tw = ns::twice; static int use(int v) { return tw(v) + 3; } };
template <class P> int use(int v) { using O = Ops<P>; return O::tw(v) + 1; }
int main() {
    std::printf("%d %d %d %d %d\n", ns::twice(4), Ops<Pol>::tw(21), use<Pol>(5), Plain::tw(7), Plain::use(1));
    return 0;
}
