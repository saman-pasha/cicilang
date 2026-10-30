// the other unit of units_a.cpp (0.192)
#include <functional>
#include <typeinfo>
#include "units.h"
int fb() { auto l = [](int x) { return x * 1000; }; return l(10); }
int lb() { struct Loc { int f() { return 200; } }; return Loc().f(); }
namespace { int helper() { return 2; } struct S { int v = 2; virtual ~S() {} virtual int get() const { return v + 20; } }; }
static int shelper() { return 4; }
int nb() { return helper(); }
int sb() { return shelper(); }
std::function<int(int)> hb() { return [](int x) { return x * 3; }; }
int gb() { auto g = [](auto x) { return x + 50; }; return g(1); }
int pb() { int (*p)(int) = [](int x) { return x - 2; }; return p(10); }
int vb() { S s; const S &r = s; return r.get(); }
int ib() { return gl.n * 1000 + gc.n * 100 + UA::sc.n * 10 + UA::sl.n + iv++ + bump() * 10000; }
const char *tb() { return typeid(S).name(); }
bool same_b(const std::type_info &t) { return t == typeid(S); }
static const std::type_info &tl() { auto l = [] {}; return typeid(l); }
static const std::type_info &tq() { struct Q {}; return typeid(Q); }
const std::type_info &tlb() { return tl(); }
const std::type_info &tqb() { return tq(); }
