#include <cstdio>
#include <compare>

// C++20: a defaulted comparison over a BASE sub-object and an ARRAY member ([class.compare.default]/6:
// the bases in declaration order, then the members; an array element by element).
struct Base {
    int tag;
    bool operator==(const Base &) const = default;
    std::strong_ordering operator<=>(const Base &) const = default;
};
struct Rec : Base {
    int a;
    int arr[3];
    char c;
    bool operator==(const Rec &) const = default;
    std::strong_ordering operator<=>(const Rec &) const = default;
};
struct Grid {
    int cells[2][2];
    bool operator==(const Grid &) const = default;
};
int main() {
    Rec x = {{1}, 2, {3, 4, 5}, 'q'};
    Rec y = x;
    Rec z = x;
    z.arr[2] = 9;
    Rec w = x;
    w.tag = 0;
    printf("%d %d %d %d\n", x == y, x == z, x == w, x != w);
    printf("%d %d %d %d\n", (x <=> y) == 0, (x <=> z) < 0, (z <=> x) > 0, (x <=> w) > 0);
    printf("%d %d %d\n", x < z, w < x, x >= y);
    Grid g = {{{1, 2}, {3, 4}}};
    Grid h = g;
    h.cells[1][0] = 0;
    printf("%d %d\n", g == g, g == h);
    return 0;
}
