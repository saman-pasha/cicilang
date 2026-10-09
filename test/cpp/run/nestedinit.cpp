// a member of a NESTED class built from a prvalue of its own class, in a class and in a class template
// (libc++'s uniform_int_distribution holds `param_type __p_' and builds it `__p_(param_type(__a, __b))')
#include <cstdio>
class Dist {
public:
  class Param {
    int a_, b_;
  public:
    Param(int a, int b) : a_(a), b_(b) {}
    int a() const { return a_; }
    int b() const { return b_; }
  };
private:
  Param p_;
public:
  Dist(int a, int b) : p_(Param(a, b)) {}
  int span() const { return p_.b() - p_.a(); }
};
template <class T> class TDist {
public:
  class Param {
    T a_, b_;
  public:
    explicit Param(T a = 0, T b = 100) : a_(a), b_(b) {}
    T a() const { return a_; }
    T b() const { return b_; }
  };
private:
  Param p_;
public:
  explicit TDist(T a = 0, T b = 100) : p_(Param(a, b)) {}
  T span() const { return p_.b() - p_.a(); }
};
int main() {
  Dist d(3, 10);
  TDist<long> t(5, 50);
  TDist<int> u;
  std::printf("%d %ld %d\n", d.span(), t.span(), u.span());
  return 0;
}
