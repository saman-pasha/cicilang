#include <cstdio>
#include <string>
// an initialization that throws: what it built destroyed, the last first ([except.ctor]/3), an array's elements too
// ([dcl.init.aggr]/9), a new-expression's block freed ([expr.new]/26), a static local tried again ([stmt.dcl]/4)
static int live = 0, made = 0, limit = 3;
struct T {
  int k;
  std::string s;
  T() : k(made++), s("an element long enough to allocate its own block") { if (k == limit) throw 7; ++live; }
  ~T() { --live; }
};
static int tries = 0;
static int f() { if (++tries < 3) throw 8; return 40 + tries; }
static int sget() { static int x = f(); return x; }
static T &tget() { static T t; return t; }
static T *aget() { static T arr[4]; return arr; }
int main() {
  try { T arr[5]; (void) arr; } catch (int) {}
  std::printf("local %d\n", live);
  made = 0;
  try { T *p = new T[5]; delete[] p; } catch (int) {}
  std::printf("new[] %d\n", live);
  made = 0;
  try { T *p = new T[2]{}; std::printf("two %d\n", live); delete[] p; } catch (int) {}
  std::printf("after %d\n", live);
  for (int i = 0; i < 3; ++i) { try { std::printf("s %d\n", sget()); } catch (int e) { std::printf("threw %d\n", e); } }
  made = 3;
  for (int i = 0; i < 2; ++i) { try { std::printf("t %d\n", tget().k); } catch (int e) { std::printf("threw %d\n", e); } }
  made = 0;
  limit = 2;
  for (int i = 0; i < 2; ++i) { try { std::printf("a %d\n", aget()[3].k); } catch (int e) { std::printf("threw %d %d\n", e, live); } }
  return 0;
}
