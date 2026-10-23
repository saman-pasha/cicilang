// a class prvalue bound to a reference parameter is destroyed at the end of its full expression ([class.temporary]/4)
#include <cstdio>
#include <string>
struct V {
    std::string s; int id;
    V(int k) : s(40, 'x'), id(k) { std::printf("ctor %d\n", id); }
    V(const V &o) : s(o.s), id(o.id + 100) { std::printf("copy %d\n", id); }
    V(V &&o) : s(std::move(o.s)), id(o.id + 200) { std::printf("move %d\n", id); }
    V &operator=(const V &o) { s = o.s; std::printf("assign %d <- %d\n", id, o.id); return *this; }
    V &operator=(V &&o) { s = std::move(o.s); std::printf("massign %d <- %d\n", id, o.id); return *this; }
    ~V() { std::printf("dtor %d\n", id); }
};
V make(int k) { return V(k); }
void cref(const V &v) { std::printf("cref %d\n", v.id); }
void rref(V &&v) { std::printf("rref %d\n", v.id); }
int main() {
    cref(make(1));
    std::printf("after 1\n");
    rref(make(2));
    std::printf("after 2\n");
    V a(3);
    a = make(4);
    std::printf("after 4\n");
    const V &e = make(5);
    std::printf("extended %d\n", e.id);
    cref(V(6));
    std::printf("after 6\n");
}
