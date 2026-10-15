// A member function's result names a further instance of the class's own template; nothing completes it (valarray's
// __val_expr<__slice_expr<E>>): the instances wait until one is used.
#include <cstdio>
template <class E> struct Wrap { E e; int get() const { return e.get() + 1; } };
template <class E> struct Expr {
  E e;
  Expr<Wrap<E>> wrap() const { return Expr<Wrap<E>>{Wrap<E>{e}}; }
  int get() const { return e.get(); }
};
struct Leaf { int v; int get() const { return v; } };
int main() { Expr<Leaf> x{Leaf{40}}; std::printf("%d %d\n", x.get(), x.wrap().wrap().get()); return 0; }
