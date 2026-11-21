// THE GLOBAL MACROS YIELD IN C++ (1.6.9, the owner's rule: "Yes user implemented should win over ccllib's macros"): a
// program's own format, print, println and clone are its own -- a function of the file, a function of a namespace
// called in it and through a using-declaration, a local lambda, and a member of the class or of a base, called in the
// class, in a nested class, out of the class and out of it by a namespace's path, in a constructor's mem-initializer,
// in a destructor and through a pointer member -- and a class with no member of the name, and main after the lambda's
// block, call the global macro still; clang++'s build of the twin, where printf stands for the macro, prints them
#include <cstdio>
static void println(const char *s) { std::printf("mine: %s\n", s); }
namespace app {
  const char *format(int n) { return n > 1 ? "many" : "one"; }
  const char *show() { return format(2); }
}
struct Box {
  int v;
  void show() const { print(7); }
  void print(int k) const { std::printf("box %d %d\n", v, k); }
  void later() const;
};
void Box::later() const { print(8); }
struct Derived : Box { void go() const { print(9); } };
struct Counter {
  static int print(int x) { return x * 2; }
  int v;
  Counter();
  ~Counter();
};
Counter::Counter() : v(print(21)) { }
Counter::~Counter() { std::printf("counter %d %d\n", v, print(1)); }
struct Outer {
  static void print(const char *s) { std::printf("outer %s\n", s); }
  struct Inner { void f() const { print("from a nested class"); } };
};
struct P {
  int x;
  P clone(int d) const { return P{x + d}; }
  P twice() const { P a = clone(1); return a.clone(10); }
};
namespace ns { struct Q { static int print(int x) { return x + 100; } int g() const; }; }
int ns::Q::g() const { return print(3); }
static int out(const char *s) { return std::printf("pointer %s\n", s); }
struct Hook { int (*print)(const char *); void f() const { print("member"); } };
struct Plain {
  int n = 4;
  void f() const { int k = n; print("the global macro in a class with no such member: {}\n", k); }
};
int main() {
  println("hi");
  std::printf("%s\n", app::show());
  { using app::format; std::printf("%s\n", format(1)); }
  Box bx{3}; bx.show(); bx.later();
  Derived d; d.v = 5; d.go();
  { Counter c; std::printf("made %d\n", c.v); }
  Outer::Inner in; in.f();
  P p{1}; std::printf("%d\n", p.twice().x);
  ns::Q q; std::printf("%d\n", q.g());
  Hook h{out}; h.f();
  { auto print = [](const char *s) { std::printf("lambda %s\n", s); }; print("x"); }
  Plain pl; pl.f();
  print("and in main after the lambda's block: {}\n", 6);
  return 0;
}
