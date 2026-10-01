// A non-const member is no candidate on a const object ([over.match.funcs]/5): `has_get<const A>' is false,
// and a const object takes the const overload.
#include <concepts>
#include <cstdio>

template <class T> concept has_get = requires (T &t) { t.get(); };

struct A { int v = 1; int get() { return v; } };
struct B { int v = 2; int get() { return v; } int get() const { return v + 10; } };

template <class T> int pick() { return has_get<const T> ? 1 : 0; }

int main() {
  const B b;
  A a;
  B c;
  std::printf("%d %d %d %d %d %d\n", pick<A>(), pick<B>(), has_get<A> ? 1 : 0, b.get(), a.get(), c.get());
  return 0;
}
