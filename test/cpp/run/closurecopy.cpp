#include <cstdio>
#include <string>
struct Tag { static int made, gone; int n; Tag(int k) : n(k) { made++; } Tag(const Tag &o) : n(o.n) { made++; } ~Tag() { gone++; } };
int Tag::made = 0, Tag::gone = 0;
struct H {
    int v; Tag t;
    H(int k) : v(k), t(k) {}
    ~H() {}
    int later() const { auto f = [*this](int d) { return v + t.n + d; }; return f(1); }
};
int main() {
    std::string s = "hello, closure";
    auto f = [s](int k) { return (int) s.size() + k; };
    printf("%d\n", f(1));
    { Tag t(7); auto g = [t](int d) { return t.n + d; }; printf("%d\n", g(3)); }
    printf("%d %d\n", Tag::made, Tag::gone);
    { H h(5); printf("%d\n", h.later()); }
    printf("%d %d\n", Tag::made, Tag::gone);
    return 0;
}
