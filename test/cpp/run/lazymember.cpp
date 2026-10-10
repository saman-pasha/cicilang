// A member of a class template's instance is instantiated where it is used ([temp.inst]/3), the
// program's own templates as the library's (0.127): a member nothing calls may name what its
// arguments lack. Eager, `D<Q>' walked `sum()' over a Q without `x' and refused the program.
#include <cstdio>
#include <vector>

struct P { int x = 4; };
struct Q { int y = 5; };
template <class T> struct D : T {
  int sum() { return this->x + 1; }        // only for a T with x
  int twice() { return 2 * get(); }
  int get() { return 7; }
  void bad() { T::no_such_function(); }    // never called, never instantiated
  static int counter;
};
template <class T> int D<T>::counter = 3;

template <class T> struct Holder {
  T t;
  explicit Holder(T v) : t(v) {}
  void print() const { std::printf("%d\n", t.size()); }   // never called for an int
  int value() const { return (int) t; }
  virtual ~Holder() {}
  virtual int kind() const { return 1; }                  // a virtual member is used by the table
};
template <class T> struct Stack {
  std::vector<T> items;
  void push(const T &v) { items.push_back(v); }
  T pop() { T v = items.back(); items.pop_back(); return v; }
  T top_plus(int k) const { return items.back() + k; }    // never called for a T without `+'
};
struct Pt { int a, b; };

int main() {
  D<P> a;
  D<Q> b;
  std::printf("%d %d %d %d\n", a.sum(), b.twice(), b.get(), D<Q>::counter);
  Holder<int> h{9};
  const Holder<int> &r = h;
  std::printf("%d %d\n", h.value(), r.kind());
  Stack<Pt> s;
  s.push(Pt{1, 2});
  s.push(Pt{3, 4});
  Pt p = s.pop();
  std::printf("%d %d %zu\n", p.a, p.b, s.items.size());
  return 0;
}
