// An operator over an enumeration operand takes a free operator only where its parameters take the operands, as over
// a class (1.6.6): `i | Green' of an int beside `Mask operator|(Mask, Color)' is the built-in operator
#include <cstdio>
enum Color { Red = 1, Green = 2, Blue = 4 };
struct Mask { int m; };
Mask operator|(Mask a, Color c) { return Mask{a.m | c}; }
Mask operator&(Color c, Mask a) { return Mask{a.m & c}; }
enum class Flag : unsigned { A = 1, B = 2 };
Flag operator|(Flag x, Flag y) { return Flag(unsigned(x) | unsigned(y)); }
struct Weight { int w; };
int operator+(Weight w, Color c) { return w.w + c * 10; }
template <class E> struct Box {
    E v;
    friend Box operator+(const Box &a, const Box &b) { return Box{a.v + b.v}; }
    friend bool operator<(const Box &a, const Box &b) { return a.v < b.v; }
};
int main() {
    int i = 8;
    int r1 = i | Green, r2 = Blue & 5, r4 = Red + Green;
    Mask m = Mask{1} | Blue, n = Green & Mask{3};
    Flag f = Flag::A | Flag::B;
    int r3 = Weight{1} + Green;
    std::printf("built-in: %d %d %d\n", r1, r2, r4);
    std::printf("free: %d %d %u %d\n", m.m, n.m, unsigned(f), r3);
    Box<int> a{1}, b{2};
    std::printf("hidden friends: %d %d\n", (a + b).v, a < b);
    return 0;
}
