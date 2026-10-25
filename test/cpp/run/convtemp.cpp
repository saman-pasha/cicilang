// A class prvalue converted through its conversion function is a temporary of the statement: the function is called on
// that object, and it is destroyed at the end of the full-expression ([class.temporary]/4). An `auto' result deduced
// while a statement is walked registers no temporary of that statement (0.206) -- libc++ 21's std::out_ptr is so.
#include <cstdio>
static int cell = 42;
static int got = 0;
struct Out {
  int *p = nullptr;
  Out() = default;
  Out(const Out &) = delete;
  ~Out() { got = p ? *p : -1; std::printf("~Out %d\n", got); }
  operator int **() { return &p; }
};
template <class T> auto out(T) { return Out(); }
static void fill(int **pp) { *pp = &cell; std::printf("fill\n"); }
struct Meters {
  double v;
  ~Meters() { std::printf("~Meters %.1f\n", v); }
  operator double() const { return v; }
};
Meters make(double v) { return Meters{v}; }
int main() {
  fill(out(0));
  std::printf("got %d\n", got);
  double d = make(2.5) * 2;
  std::printf("d %.1f\n", d);
  long n = (long) make(7.0);
  std::printf("n %ld\n", n);
}
