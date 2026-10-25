// A member template with an explicit object parameter called with its template arguments given deduces its Self from
// the object the call is made on, through an object, a const object and a pointer ([dcl.fct]/6; 0.206) -- C++26's
// variant::visit<R>(f) in libc++ 21 is written so.
#include <cstdio>
struct V {
  int x = 5;
  template <int = 0, class Self, class F> decltype(auto) visit(this Self &&self, F &&f) { return f(self.x); }
  template <class R, class Self, class F> R visit(this Self &&self, F &&f) { return static_cast<R>(f(self.x)); }
};
int main() {
  V v;
  int a = v.visit([](int x) { return x * 2; });
  long b = v.visit<long>([](int x) { return x + 1; });
  const V cv;
  int c = cv.visit<int>([](int x) { return x * 3; });
  V *p = &v;
  int d = p->visit<int>([](int x) { return x - 1; });
  std::printf("%d %ld %d %d\n", a, b, c, d);
}
