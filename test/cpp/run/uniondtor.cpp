// A UNION'S DESTRUCTOR DESTROYS NO MEMBER (0.121; [class.dtor]/16): the members share their storage, and which one is alive is the program's to
// say. A union class with `~U() {}' ends its life with that body alone; the program destroys the member it constructed. (libc++ 18's
// `__union' of std::variant is such a union: every member destroyed by the union's destructor freed a string twice.)
#include <cstdio>
struct D { int id; D(int i) : id(i) { std::printf("ctor %d\n", id); } ~D() { std::printf("dtor %d\n", id); } };
union U {
  D d;
  int i;
  U(int x) : d(x) {}
  ~U() { std::printf("union gone\n"); }
};
template <class T> union Slot {
  T value;
  char dummy;
  Slot() : dummy(0) {}
  template <class... A> Slot(int, A &&... a) : value(static_cast<A &&>(a)...) {}
  ~Slot() {}
};
int main() {
  { U u(1); }
  std::printf("after\n");
  U u2(2);
  u2.d.~D();
  Slot<D> s(0, 3);
  s.value.~D();
  Slot<D> t;
  std::printf("end\n");
  return 0;
}
