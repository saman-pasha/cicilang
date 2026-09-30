// a class template's instance over a class still being registered (the CRTP): its constraint sees a class, its members come where they are used (0.110)
#include <cstdio>
#include <type_traits>
template <class D> requires std::is_class_v<D> struct iface {
  int twice() const { return static_cast<const D &>(*this).get() * 2; }
};
template <class T> struct box : iface<box<T>> { T v; box(T x) : v(x) {} T get() const { return v; } };
int main() { box<int> b(21); std::printf("%d %d\n", b.twice(), (int) std::is_class_v<box<int>>); return 0; }
