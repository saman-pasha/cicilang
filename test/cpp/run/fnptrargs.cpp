// fnptrargs: a call through a pointer or a reference to function takes its arguments through the passes a call by name gives
// them, read off the FUNCTION TYPE: a reference parameter its object (a std::reference_wrapper through its conversion operator,
// `std::thread t(bump, std::ref(c), 500)' and `std::invoke(bump, std::ref(c), 5)'), a class taken by value its copy, a `const
// long &' its converted temporary. They took none: the callee was handed the wrapper's address as the Counter, and a Tag the caller
// still owned.
#include <cstdio>
#include <functional>

struct Counter {
  long a = 1;
  long b = 2;
  long total = 0;
  void add(long n) { total += n; }
};

struct Tag {
  int v;
  Tag(int x) : v(x) {}
  Tag(const Tag &o) : v(o.v + 100) { std::printf("copy %d\n", o.v); }
  ~Tag() { std::printf("~Tag %d\n", v); }
};

void bump(Counter &c, int times) { for (int i = 0; i < times; i++) c.add(2); }
void bumpi(int &c, int times) { c += times; }
void take(Tag t) { std::printf("take %d\n", t.v); }
void takeref(const Tag &t) { std::printf("takeref %d\n", t.v); }
long widen(const long &x) { return x + 1; }

int main() {
  Counter c;
  auto r = std::ref(c);
  bump(r, 3);                                  // a reference_wrapper where a Counter & is wanted: the conversion operator
  std::printf("%ld\n", c.total);
  std::invoke(bump, std::ref(c), 5);           // ... through std::invoke, a call through a function reference
  std::printf("%ld\n", c.total);
  int n = 1;
  std::invoke(bumpi, std::ref(n), 5);
  std::printf("%d\n", n);
  void (*fp)(Counter &, int) = bump;           // ... through a function pointer
  fp(r, 2);
  fp(c, 1);
  std::printf("%ld\n", c.total);
  void (&fr)(int &, int) = bumpi;              // ... and a reference to a function
  fr(n, 4);
  std::printf("%d\n", n);
  Tag a(1);
  void (*tp)(Tag) = take;                      // a class taken by value is COPIED for the callee, which destroys its own
  tp(a);
  void (*tr)(const Tag &) = takeref;
  tr(a);
  long (*wp)(const long &) = widen;            // an int where a `const long &' is wanted: a temporary of the referent's type
  std::printf("%ld\n", wp(41));
  std::printf("end\n");
  return 0;
}
