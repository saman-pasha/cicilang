// C++17'S AGGREGATES THAT 1.6.55'S RULES KEEP: a class whose one constructor is `X() = delete' is an aggregate in C++17 (its constructor
// is user-declared, not user-provided; [dcl.init.aggr]/1 of C++17), and braces initialize it member by member, no constructor run --
// where C++20 refuses them (test/cpp/defctor_*.cpp); the reader writes `X{}' and `X()' alike, so a value-initialization of such an
// aggregate is not asked
#include <cstdio>
struct Agg { Agg() = delete; int v; };
struct Two { Two() = delete; int a; int b; };
struct NU2 { Agg a; int k = 1; };                        // its implicit default constructor, which a deletes, made with its class and never called
int main() {
  Agg a{}; Agg b{3}; Two t{4, 5};
  Agg *p = new Agg{};
  NU2 n2{{7}, 8};
  int w = Agg{}.v + Agg{6}.v;
  std::printf("%d %d %d %d %d %d %d %d\n", a.v, b.v, t.a, t.b, p->v, w, n2.a.v, n2.k);
  delete p;
  return 0;
}
