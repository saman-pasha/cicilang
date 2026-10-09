// a MEMBER TEMPLATE of a plain class defined out of it (0.117): a constructor template and a method template, both declared in the class and defined below
// it -- libc++'s std::mutex and std::thread hold constructors of this shape. The declaration, registered bodyless, takes the body of the definition (cpp_refresh_mts)
#include <cstdio>
struct T {
  template <class F> explicit T(F f, int x);
  template <class G> int apply(G g);
  int v;
};
template <class F> T::T(F f, int x) : v(f(x)) {}
template <class G> int T::apply(G g) { return g(v) + 1; }
int twice(int a) { return 2 * a; }
int main() {
  T t(twice, 21);
  std::printf("%d %d\n", t.v, t.apply(twice));
  return 0;
}
