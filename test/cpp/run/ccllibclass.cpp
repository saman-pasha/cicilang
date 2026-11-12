// A CLASS THAT HOLDS AN INSTANCE'S OBJECT (0.297): a member of an instance's type that a constructor names by no
// initializer is born zero, as std::vector's default constructor makes its vector empty, and so is one under a member
// object's class; `: items()' value-initializes it, a memset over a member not yet given anything; a class with no
// constructor of its own -- a data-only one, one with a member function, one with virtual functions -- declared with no
// initializer is born `{}'. Each is empty at its first use over storage written with garbage first
#include <cstdio>
#include <vector.pl>
static void scribble() noexcept { volatile unsigned char junk[1024]; for (int i = 0; i < 1024; i++) junk[i] = (unsigned char)(0x5A + i); (void)junk[0]; }
struct Named { vector<int> items; int n; Named() : n(7) {} };
struct Valued { vector<int> items; int n; Valued() : items(), n(7) {} };
struct Plain { vector<int> items; int n; };
struct Method { vector<int> items; int twice(int k) const noexcept { return 2 * k; } };
struct Base { virtual int id() const noexcept { return 1; } virtual ~Base() {} };
struct Virtual : Base { vector<int> items; int id() const noexcept override { return 2; } };
struct In { vector<int> v; int k; };
struct Out { In in; int n; Out() : n(4) {} };
static int named() { Named h; push_back(h.items, 3); int k = (int)len(h.items) + h.n; vector_int_drop(&h.items); return k; }
static int valued() { Valued h; push_back(h.items, 3); int k = (int)len(h.items) + h.n; vector_int_drop(&h.items); return k; }
static int plain() { Plain p; push_back(p.items, 3); int k = (int)len(p.items) + p.n; vector_int_drop(&p.items); return k; }
static int method() { Method h; push_back(h.items, 3); int k = (int)len(h.items) + h.twice(2); vector_int_drop(&h.items); return k; }
static int braces() { Method h{}; push_back(h.items, 3); int k = (int)len(h.items) + h.twice(2); vector_int_drop(&h.items); return k; }
static int virt() { Virtual h; push_back(h.items, 3); int k = (int)len(h.items) + h.id(); vector_int_drop(&h.items); return k; }
static int member() { Out o; push_back(o.in.v, 3); int k = (int)len(o.in.v) + o.n + o.in.k; vector_int_drop(&o.in.v); return k; }
int main() {
    int r[7];
    scribble(); r[0] = named();
    scribble(); r[1] = valued();
    scribble(); r[2] = plain();
    scribble(); r[3] = method();
    scribble(); r[4] = braces();
    scribble(); r[5] = virt();
    scribble(); r[6] = member();
    std::printf("%d %d %d %d %d %d %d\n", r[0], r[1], r[2], r[3], r[4], r[5], r[6]);
    return 0;
}
