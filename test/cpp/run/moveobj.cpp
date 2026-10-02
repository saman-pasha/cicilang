// A member function called on `std::move(x)' takes x itself as its object; the xvalue chooses the &&-qualified
// overload. libc++ 18's __format_buffer::__out_it() && writes `std::move(__writer_).__out_it()'.
#include <cstdio>
#include <utility>
struct W {
  int v = 3;
  int take() && { return v * 2; }
  int take() & { return v; }
};
struct B {
  W w;
  int out() && { return std::move(w).take(); }
  int peek() { return w.take(); }
};
int main() {
  B b;
  int a = b.peek();
  int c = std::move(b).out();
  W x;
  x.v = 10;
  int d = std::move(x).take();
  std::printf("%d %d %d\n", a, c, d);
  return 0;
}
