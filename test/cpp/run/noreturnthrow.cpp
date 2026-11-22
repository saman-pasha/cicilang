// A THROW ENDS ITS PATH, AND A [[noreturn]] FUNCTION THAT THROWS, ABORTS IN A HANDLER, RETHROWS OR LOOPS IS NONE THAT
// RETURNS (1.6.17): each builds, as clang++ builds it -- a function whose end is reached by none of its paths is not
// refused; a function not so declared whose every path throws or exits ends its caller's path, and the handler is
// entered from the call. A noexcept one whose body exits, one not so declared whose noexcept body exits, one whose local's
// destructor `exit' does not run, and one whose range-for a break leaves before the exit
#include <cstdio>
#include <cstdlib>
[[noreturn]] static void bounce(int c) { throw c; }
[[noreturn]] static void again() { try { throw 1; } catch (...) { throw; } }
[[noreturn]] static void quit(int c) noexcept { std::fflush(stdout); std::exit(c); }
struct Loud { int v; ~Loud() { std::printf("~Loud %d\n", v); } };
[[noreturn]] static void loud_exit(int c) { Loud l{c}; std::fflush(stdout); std::exit(c); }
static void bad(int x) { throw x; }
static void quit2(int c) noexcept { std::fflush(stdout); std::exit(c); }
static void ranged(int c) { int a[3] = {1, 2, 3}; for (int x : a) { if (x == c) break; } std::fflush(stdout); std::exit(c); }
static int f(int x) { if (x > 2) bad(x); return x; }
static int pick(int x) {
    int *p = new int(x);
    if (x > 9) { delete p; bounce(x); }
    int r = *p;
    delete p;
    return r;
}
static int twice() { try { again(); } catch (int e) { return e * 2; } }
int main(int argc, char **) {
    int r = 0;
    try { r = f(1) + f(5); } catch (int e) { r = -e; }
    int s = 0;
    try { s = pick(3) + pick(20); } catch (int e) { s = e; }
    std::printf("%d %d %d\n", r, s, twice());
    if (argc > 3) quit(9);
    if (argc > 2) { int *q = new int(1); *q = 2; quit2(*q); }
    if (argc > 4) { int *q2 = new int(1); *q2 = 3; ranged(*q2); }
    loud_exit(0);
}
