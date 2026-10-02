// direct-initialization from an object of a class derived VIRTUALLY from the parameter's class: the explicit
// constructor over the base's reference, never the private copy constructor declared and not defined
#include <cstdio>
struct Base { int f = 7; virtual ~Base() {} };
struct Der : virtual Base { int g = 1; };
template <class T> class Saver {
  Base &b_; int v_;
  Saver(const Saver &);
  Saver &operator=(const Saver &);
public:
  explicit Saver(Base &b) : b_(b), v_(b.f) {}
  ~Saver() { b_.f = v_; }
};
template <class T> int use(Der &d) { Saver<T> s(d); d.f = 9; return d.f; }
int main() {
  Der d; int x = use<int>(d);
  std::printf("%d %d\n", x, d.f);
  { Saver<char> t(d); d.f = 3; }
  std::printf("%d\n", d.f);
  return 0;
}
