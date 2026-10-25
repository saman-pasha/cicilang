// The C++ gate's by-value check (0.207): a by-value parameter of a class with a destructor crosses a call between code
// that clang++ built (byval_helper.cpp) and code that cicilang++ built (byval_main.cpp), both ways, and the caller
// destroys it, once, at the end of its full-expression, as the Itanium C++ ABI (3.1.2.3) has it. The functions have C
// linkage: the program's own functions keep their own names here.
#include <cstdio>
extern "C" int byval_live;   // the objects made and not yet destroyed (byval_helper.cpp)
struct T {
  int v;
  T(int x) : v(x) { byval_live++; }
  T(const T &o) : v(o.v + 100) { byval_live++; }
  ~T() { byval_live--; std::printf("~T(%d) ", v); }
};
extern "C" {
int there(T t);         // clang++'s
int here(T t);          // cicilang++'s
int call_here(int x);   // clang++'s: here of a prvalue and of a copy
}
