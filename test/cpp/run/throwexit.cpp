#include <cstdio>
// a throwing destructor at an exit that leaves some tries and not others: a return out of an inner try, a goto out of a
// try, a break and a continue, a return in a handler; and a return out of a loop over a local the exit destroys
struct D { int n; ~D() noexcept(false) { std::printf("~D%d\n", n); if (n % 2 == 0) throw n; } };
int nested() {
  try {
    D mid{4};
    try { D in{1}; return 7; } catch (int e) { std::printf("inner wrong %d\n", e); }
    std::printf("after inner\n");
  } catch (int e) { std::printf("outer caught %d\n", e); }
  return 8;
}
int jump(int k) {
  D a{3};
  try {
    D b{6};
    if (k) goto out;
    std::printf("no jump\n");
  } catch (int e) { std::printf("jump caught %d\n", e); return 1; }
out:
  std::printf("out\n");
  return 2;
}
int inloop() {
  int r = 0;
  for (int i = 0; i < 3; i++) {
    D x{i * 2 + 1};
    try {
      D y{10};
      if (i == 1) continue;
      if (i == 2) break;
    } catch (int e) { std::printf("loop %d caught %d\n", i, e); r += e; }
  }
  return r;
}
struct H { int n; ~H() { std::printf("~H%d\n", n); } };
int handler_return() {
  H h{1};
  try { throw 5; } catch (int e) { D d{12}; std::printf("in handler %d\n", e); return e; }
  return 0;
}
int fromloop(int k) {
  H h{1};
  for (int i = 0; i < 3; i++) { H d{i + 2}; if (i == k) return 3; }
  return 4;
}
int main() {
  std::printf("nested %d\n", nested());
  std::printf("jump0 %d\n", jump(0));
  std::printf("jump1 %d\n", jump(1));
  std::printf("inloop %d\n", inloop());
  try { std::printf("hr %d\n", handler_return()); } catch (int e) { std::printf("hr caught %d\n", e); }
  std::printf("fromloop %d %d\n", fromloop(1), fromloop(5));
  return 0;
}
