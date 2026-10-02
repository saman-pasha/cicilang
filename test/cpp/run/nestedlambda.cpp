// a lambda capturing this in a nested class's method reaches the nested class's members and, by name, the enclosing
// class's statics, types and enumerators
#include <cstdio>
struct Outer {
  static int scale;
  enum Mode { Low = 1, High = 3 };
  using Num = long;
  struct Inner {
    int b = 2;
    Num f() { auto l = [this] { Num k = b * scale; return k + High; }; return l(); }
    int g() { auto l = [&] { return b + Low + scale; }; return l(); }
  };
};
int Outer::scale = 10;
int main() { Outer::Inner i; std::printf("%ld %d\n", i.f(), i.g()); return 0; }
