// THE FUNCTIONS OF A NAMESPACE AND OF AN `extern "C"' BLOCK ARE WALKED BY THE SAFE PART (1.6.16), and what is right in them
// builds as at file scope: a free function, a nested namespace's class with its members, an inline namespace's, an
// anonymous namespace's, an `extern "C"' block's in a namespace and at file scope, a function whose every return is
// static storage, its result read and never freed, a function that keeps its parameter in a global vector handed a
// global's address, and one that stores into a static own array, its element borrowed again after the call
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <vector>
namespace app {
int sum(const int *v, int n) {
    int *acc = new int(0);
    for (int i = 0; i < n; i++) *acc += v[i];
    int r = *acc;
    delete acc;
    return r;
}
namespace shapes {
struct Box {
    std::unique_ptr<int> side;
    explicit Box(int s) : side(std::make_unique<int>(s)) {}
    int area() const { return *side * *side; }
};
}
inline namespace v1 { int twice(int x) { auto u = std::make_unique<int>(x); return *u * 2; } }
namespace { int hidden(int x) { int *p = new int(x); int r = *p + 1; delete p; return r; } }
extern "C" int c_side(int x) { return x + 3; }
}
extern "C" { int plain_c(int x) { int *p = new int(x); int r = *p * 3; delete p; return r; } }
namespace tbl {
int table[4] = {10, 20, 30, 40};
int *row(int i) { return table + i; }
}
namespace reg {
std::vector<int *> g;
int keep = 7;
void add(int *p) { g.push_back(p); }
}
struct thing { int v; };
static own thing *make(int v) noexcept {
    own thing *t = (thing *)malloc(sizeof *t);
    if (t) t->v = v;
    return t;
}
static own thing *slot[2];
namespace fill {
void refill() noexcept {
    free(slot[0]);
    slot[0] = make(2);
}
}
int main() {
    int v[] = {1, 2, 3, 4};
    app::shapes::Box b(5);
    std::printf("%d %d %d %d %d %d\n", app::sum(v, 4), b.area(), app::twice(4), app::hidden(5), app::c_side(6), plain_c(7));
    int *r = tbl::row(2);
    std::printf("%d\n", *r);
    reg::add(&reg::keep);
    std::printf("%zu %d\n", reg::g.size(), *reg::g[0]);
    slot[0] = make(1);
    fill::refill();
    thing *e = slot[0];
    if (e) std::printf("%d\n", e->v);
    free(slot[0]);
    return 0;
}
