// a local `std::lock_guard<std::mutex> g(mu);' in a member function, with the mutex declared LATER in the class (0.117, reader 114): a class body is a
// complete-class context ([class.mem]/6), so `mu' is a member the reader has not met yet -- and `g(mu)' was read as the declaration of a function g
// taking an unnamed parameter of the type `mu' (the vexing parse), where in a body an undeclared lone name is the argument of an object. The
// unnamed-parameter rule is for a prototype whose type no included header declares
#include <cstdio>
#include <mutex>
class Counter {
 public:
  void add(long n) {
    std::lock_guard<std::mutex> g(mu);
    total += n;
  }
  long get() {
    std::unique_lock<std::mutex> l(mu);
    return total;
  }
 private:
  std::mutex mu;
  long total = 0;
};
struct Early {
  std::mutex m;
  long v = 0;
  void bump() { std::lock_guard<std::mutex> g(m); v++; }
};
int main() {
  Counter c;
  c.add(5);
  c.add(37);
  Early e;
  e.bump();
  e.bump();
  std::printf("%ld %ld\n", c.get(), e.v);
  return 0;
}
