// The scan ahead of a class body (0.183): a member template's head that holds a comparison in parentheses, `(I < 3)',
// counted that `<' as an angle bracket, ran past the class's end and noted the next `Name (' it met -- here `Box (' in
// a global's initializer -- as a member FUNCTION template, so `Box<int>' was no type: the deduction guide after it was
// a syntax error. libc++ 21's <variant> heads hold `(_Ip < sizeof...(_Types))', and the scan noted `shared_ptr', 2,600
// lines on: <mutex>'s read stopped at shared_ptr's deduction guide, and any read after it in the process too.
#include <cstdio>
#include <type_traits>

template <class T> struct Box {
  T v;
  Box(T x) : v(x) {}
};
template <class T> Box(T) -> Box<T>;

struct Tag {
  int n;
  operator int() const { return n; }
};

struct V {
  template <unsigned I, class = typename std::enable_if<(I < 3)>::type>
  int get() const { return I + 10; }
};

bool big = 5 > Box(4).v;
Box(Tag) -> Box<int>;

int main() {
  Box<int> b{7};
  Box<long> c(8L);
  Box q(Tag{9});
  std::printf("%d %d %d %ld %d\n", V{}.get<2>(), (int)big, b.v, c.v, q.v);
  return 0;
}
