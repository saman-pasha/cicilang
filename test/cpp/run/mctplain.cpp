// a member class template of a plain class, declared in the class and defined out of it
#include <cstdio>
struct L {
  template <class E> class M;
  template <class E> struct N { E e; };
};
template <class E> class L::M {
public:
  E v;
  M(E x) : v(x) {}
  E get() const { return v * 2; }
};
int main() {
  L::M<int> m(21);
  L::M<long> n(100);
  L::N<char> c{'q'};
  std::printf("%d %ld %c\n", m.get(), n.get(), c.e);
  return 0;
}
