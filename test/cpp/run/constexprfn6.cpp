#include <cstdio>
struct P {
    int x;
    int y;
    constexpr int sum() const { return x + y; }
    constexpr void scale(int k) { x *= k; y *= k; }
    constexpr void bump() { x++; y += 10; }
};
struct V {
    int a;
    int b;
    constexpr V(int a0, int b0) : a(a0), b(b0 * 2) {}
    constexpr int total() const { return a + b; }
    constexpr void add(int k) { a += k; }
};
constexpr int scaled_sum(int k) {
    P p = {1, 2};
    p.scale(k);
    p.bump();
    return p.sum();
}
constexpr void fill(int *a, int n, int v) {
    for (int i = 0; i < n; i++) a[i] = v + i;
}
constexpr void bump(int *p) { *p += 1; }
constexpr void swap_ints(int *a, int *b) {
    int t = *a;
    *a = *b;
    *b = t;
}
constexpr void inc_ref(int &r) { r += 100; }
constexpr int filled_sum() {
    int a[4] = {0, 0, 0, 0};
    fill(a, 4, 5);
    int s = 0;
    for (int i = 0; i < 4; i++) s += a[i];
    return s;
}
constexpr int through_pointers() {
    int x = 3;
    int y = 7;
    int *p = &x;
    *p = 40;
    bump(&y);
    swap_ints(&x, &y);
    inc_ref(x);
    int a[3] = {1, 2, 3};
    int *q = a + 1;
    q[1] = 30;
    *q = 20;
    return x * 1000 + y * 100 + a[0] + a[1] + a[2];
}
constexpr int array_sizes() {
    int a[6] = {1, 2, 3, 4, 5, 6};
    P ps[3] = {{1, 2}, {3, 4}, {5, 6}};
    long w[2] = {1, 2};
    return (int) (sizeof(a) / sizeof(a[0])) * 100 + (int) sizeof(ps) + (int) sizeof(w) + (int) sizeof(ps[1]);
}
constexpr V g(3, 4);
constexpr int ctor_local() {
    V v(1, 2);
    v.add(5);
    V w = V(10, 20);
    return v.total() * 1000 + w.total() + V(7, 1).total();
}
constexpr int ptr_to_member_obj() {
    P p = {5, 6};
    P *q = &p;
    q->x = 50;
    q->scale(2);
    return p.x + p.y;
}
template <int N> struct Box { static const int v = N; };
int main() {
    static_assert(scaled_sum(3) == 20, "scale");
    static_assert(filled_sum() == 26, "fill");
    static_assert(through_pointers() == 112051, "ptrs");
    static_assert(array_sizes() == 600 + 24 + 16 + 8, "sizes");
    static_assert(g.total() == 11, "global ctor");
    static_assert(ctor_local() == 10059, "local ctor");
    static_assert(ptr_to_member_obj() == 112, "member obj");
    printf("%d %d %d %d\n", scaled_sum(3), filled_sum(), through_pointers(), array_sizes());
    printf("%d %d %d %d\n", g.total(), g.a, ctor_local(), ptr_to_member_obj());
    printf("%d %d %d\n", Box<scaled_sum(2)>::v, Box<through_pointers() % 100>::v, Box<g.b>::v);
    P r = {1, 1};
    r.scale(4);
    V h(2, 3);
    h.add(1);
    printf("%d %d %d\n", r.sum(), h.total(), Box<ctor_local()>::v);
    return 0;
}
