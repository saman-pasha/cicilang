// two units built apart (0.192): each unit's closures, local classes, unnamed namespace, static functions and type
// information are its own, and a header's inline variables are one object -- units_b.cpp is the other unit
#include <functional>
#include <typeinfo>
#include "units.h"
int fb(); int lb(); int nb(); int sb(); int gb(); int pb(); int vb(); int ib(); const char *tb(); bool same_b(const std::type_info &);
std::function<int(int)> hb();
int fa() { auto l = [](int x) { return x + 1; }; return l(10); }
int la() { struct Loc { int f() { return 100; } }; return Loc().f(); }
namespace { int helper() { return 1; } struct S { int v = 1; virtual ~S() {} virtual int get() const { return v + 10; } }; }
namespace n { namespace { int deep() { return 300; } } int use() { return deep(); } }
static int shelper() { return 3; }
int na() { return helper() + n::use(); }
int sa() { return shelper(); }
std::function<int(int)> ha() { return [](int x) { return x * 2; }; }
int ga() { auto g = [](auto x) { return x + 5; }; return g(1); }
int pa() { int (*p)(int) = [](int x) { return x - 1; }; return p(10); }
int va() { S s; const S &r = s; return r.get(); }
const char *ta() { return typeid(S).name(); }
namespace { const char *anonfn() { return __PRETTY_FUNCTION__; } }
int main() {
  std::printf("%d %d %d %d %d %d %d %d\n", fa(), fb(), la(), lb(), na(), nb(), sa(), sb());
  std::printf("%d %d %d %d %d %d\n", ha()(5), hb()(5), ga(), gb(), pa(), pb());
  std::printf("%d %d %s %s %d %d\n", va(), vb(), ta(), tb(), (int) (typeid(S) == typeid(S)), (int) same_b(typeid(S)));
  std::printf("%d %d %d %d %d\n", gl.n + gc.n + UA::sc.n + UA::sl.n, iv, ib(), iv, bump());
  std::printf("%s\n", anonfn());
  return 0;
}
