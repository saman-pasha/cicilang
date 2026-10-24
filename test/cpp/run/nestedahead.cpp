// a nested struct used before its declaration in the class, a complete-class context ([class.mem]/6): libc++'s stop_callback
#include <cstdio>
struct Tok { int v; };
template <class Cb> class S {
public:
  template <class C2>
  explicit S(const Tok &t, C2 &&c) : S(tag{}, t.v, static_cast<C2 &&>(c)) {}
private:
  Cb cb_;
  struct tag {};
  template <class C2> S(tag, int v, C2 &&c) : cb_(static_cast<C2 &&>(c)) { if (v) cb_(); }
};
template <class Cb> S(Tok, Cb) -> S<Cb>;
struct P {
  P(int k) : P(mark{}, k) {}
  int v;
private:
  struct mark {};
  P(mark, int k) : v(k * 2) {}
};
int main() {
  int hits = 0;
  Tok t{1};
  S s(t, [&hits] { hits++; });
  P p(4);
  std::printf("%d %d\n", hits, p.v);
  return 0;
}
