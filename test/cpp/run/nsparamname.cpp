// A class declares its members' names, a function its parameters': a deeper namespace's class whose member
// function has a parameter of the collided name keeps its own name in its base clause (libc++ 22's
// `__adjacent_transform::__fn' and `operator()(_Range &&, _Fn &&__fn)').
#include <cstdio>

template <class D>
struct closure {
  int tag() const { return static_cast<const D *>(this)->k(); }
};

namespace v {
template <int N>
struct fn : closure<fn<N>> {
  int k() const { return N; }
};
namespace w {
template <int N>
struct fn : closure<fn<N>> {
  int k() const { return N * 10; }
  int call(int fn) const { return fn + N; }
};
} // namespace w
} // namespace v

int main() {
  v::fn<2> x;
  v::w::fn<3> y;
  std::printf("%d %d %d\n", x.tag(), y.tag(), y.call(4));
  return 0;
}
