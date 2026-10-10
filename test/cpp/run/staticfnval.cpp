// A static member function named bare as a value: a pointer member assigned in a method, a base's initializer
// (libc++ 21's __allocating_buffer shape: a member and a static function of one name), several static functions chosen
// by the target, a base class's static, an enclosing class's static used by a nested class.
#include <cstdio>

struct Plain {
  void (*fn)(unsigned long);
  Plain() : fn(0) {}
  void set() { fn = prep; }
  void run(unsigned long h) { fn(h); }
  static void prep(unsigned long h) { std::printf("prep %lu\n", h); }
};

template <class C>
struct Out {
  using fn_t = void (*)(Out<C> &, unsigned long);
  Out(C *, unsigned long cap, fn_t f) : cap_(cap), f_(f) {}
  void flush(unsigned long n) { f_(*this, n); }
  unsigned long cap_;
  fn_t f_;
};

template <class C>
struct Alloc : Out<C> {
  Alloc() : Out<C>{buf_, sizeof buf_, prep} {}
  C buf_[16];
  int hits_ = 0;
  int hits() const { return hits_; }

private:
  void prep(unsigned long n) {
    ++hits_;
    std::printf("member prep %lu\n", n);
  }
  static void prep(Out<C> &o, unsigned long n) { static_cast<Alloc<C> &>(o).prep(n); }
};

struct Pick {
  static void pick(int v) { std::printf("int %d\n", v); }
  static void pick(double v) { std::printf("double %.1f\n", v); }
  void (*as_int)(int);
  void (*as_double)(double);
  Pick() : as_int(pick), as_double(pick) {}
};

struct Base {
  static int twice(int v) { return 2 * v; }
};
struct Derived : Base {
  int (*f)(int);
  Derived() : f(0) {}
  int via() {
    f = twice;
    return f(21);
  }
};

struct Outer {
  static int plus1(int v) { return v + 1; }
  struct Inner {
    int (*g)(int);
    Inner() : g(plus1) {}
  };
};

int main() {
  Plain p;
  p.set();
  p.run(7);
  Alloc<char> a;
  a.flush(5);
  a.flush(6);
  std::printf("%d\n", a.hits());
  Pick k;
  k.as_int(3);
  k.as_double(2.5);
  Derived d;
  std::printf("%d\n", d.via());
  Outer::Inner in;
  std::printf("%d\n", in.g(41));
  return 0;
}
