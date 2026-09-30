#include <cstdio>
static int sq(int x) pre(x >= 0) post(r: r >= x) { return x * x; }
static void only_pos(int x) pre(x > 0) { std::printf("%d\n", x); }
struct Acc { int total = 0; void add(int v) pre(v != 0) post(total > 0) { total += v; } };
static int pick(int a) post(r: r > 0) { if (a > 1) return a; return 1; }
int main() {
    std::printf("%d %d %d\n", sq(3), pick(5), pick(-2));
    only_pos(2);
    Acc a; a.add(4); a.add(3); std::printf("%d\n", a.total);
    contract_assert(sq(2) == 4);
    std::fflush(stdout);
    only_pos(-1);
    std::printf("never\n");
    return 0;
}
