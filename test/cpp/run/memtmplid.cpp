// A MEMBER TEMPLATE CALLED WITH ITS ARGUMENTS GIVEN, through an object or a pointer (0.121): `p->f<T>(args)' had no clause (the template-id was taken
// for a method name), and `o.f<T>(args)' found only the class's own templates -- not a base's. The object is adjusted through the base
// sub-objects; a static member template takes none. libc++ 18's `variant::emplace' calls `__impl_.__emplace<_Ip>(...)' of a base of `__impl'.
#include <cstdio>
struct Base { int k = 7; template <int I, class... A> int run(A &&... a) { return I + k + (int) sizeof...(A); } };
struct D : Base { template <class T> static int stat(T t) { return (int) t + 1; } };
struct W : Base { int m = 100; template <int I> int mine(int x) { return I * x + m; } };
int main() {
  W w; W *p = &w; D d; D *q = &d;
  std::printf("%d %d %d\n", p->mine<3>(4), p->run<2>(1, 2, 3), q->run<10>());
  std::printf("%d %d %d\n", w.run<5>(), w.mine<2>(1), d.run<1>(1.5));
  std::printf("%d %d\n", q->stat<double>(2.5), D::stat<int>(4));
  return 0;
}
