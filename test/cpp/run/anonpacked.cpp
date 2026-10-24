// an anonymous packed struct in a class, as libc++ 21's string holds one: its members packed, the holder not
#include <cstddef>
#include <cstdio>
template <class C> struct S {
  typedef unsigned long size_type;
  struct L {
    struct __attribute__((__packed__)) { size_type a : 1; size_type b : 63; };
    size_type n;
    C *p;
  };
  struct Q { char c; struct __attribute__((packed)) { int i; short s; }; long l; };
  union R { L l; char raw[24]; };
  R r;
};
int main() {
  using T = S<char>;
  std::printf("%zu %zu %zu %zu\n", sizeof(T::L), alignof(T::L), sizeof(T), alignof(T));
  std::printf("%zu %zu %zu %zu\n", sizeof(T::Q), offsetof(T::Q, i), offsetof(T::Q, s), offsetof(T::Q, l));
  T t; t.r.l.a = 1; t.r.l.b = 12345; t.r.l.n = 7; t.r.l.p = nullptr;
  std::printf("%lu %lu %lu\n", (unsigned long) t.r.l.a, (unsigned long) t.r.l.b, (unsigned long) t.r.l.n);
  return 0;
}
