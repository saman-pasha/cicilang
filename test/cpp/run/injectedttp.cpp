// The injected class name as a template template argument names the class template ([temp.local]/1): libc++ 22's
// __split_buffer and its layout, the layout naming itself inside its own body.
#include <cstdio>

template <class T, class A, template <class, class, class> class L> class Buf;

template <class S, class T, class A>
class Layout {
public:
  T items[4] = {0, 0, 0, 0};
  int n = 0;
  void swap_layout(Layout<Buf<T, A, Layout>, T, A> &o) {
    for (int i = 0; i < 4; ++i) { T t = items[i]; items[i] = o.items[i]; o.items[i] = t; }
    int k = n; n = o.n; o.n = k;
  }
};

template <class T, class A, template <class, class, class> class L>
class Buf : public L<Buf<T, A, L>, T, A> {
public:
  void push(T x) { this->items[this->n++] = x; }
  T sum() const { T s = 0; for (int i = 0; i < this->n; ++i) s += this->items[i]; return s; }
};

template <class T>
struct Vec {
  template <class U, class A> using Sb = Buf<U, A, Layout>;
  Sb<T, int> b;
};

int main() {
  Vec<int> v;
  v.b.push(3);
  v.b.push(4);
  Buf<int, int, Layout> w;
  w.push(10);
  v.b.swap_layout(w);
  std::printf("%d %d %d %d\n", v.b.sum(), v.b.n, w.sum(), w.n);
  return 0;
}
