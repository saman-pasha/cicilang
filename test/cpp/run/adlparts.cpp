// ADL THROUGH A COMPOUND ARGUMENT'S PARTS ([basic.lookup.argdep]/3): a function type's parameters and its result, a
// pointer to member's class, an array's element and a template template argument's namespace each associate ns, so
// each unqualified call finds ns's function of a name that std's <algorithm> and <iterator> also use
#include <algorithm>
#include <cstdio>
#include <iterator>

namespace ns {
struct S { int v; };
struct M { int x; int f() { return x; } };
template <class T> struct Box { T t; };
int count(void (*)(S)) { return 1; }   // a function pointer: its parameter's class
int find(S (*)()) { return 2; }        // ... its result's class
int sort(int M::*) { return 3; }       // a pointer to data member: its class
int fill(int (M::*)()) { return 4; }   // a pointer to member function: its class
int size(S (&)[2]) { return 5; }       // an array: its element's class
}
template <template <class> class TT> struct Holder {};
namespace ns { int data(Holder<Box>) { return 6; } }   // a template template argument's namespace

void take(ns::S) {}
ns::S make() { return ns::S{7}; }

int main() {
  ns::S arr[2] = {{1}, {2}};
  std::printf("%d %d %d %d %d %d\n", count(take), find(make), sort(&ns::M::x), fill(&ns::M::f), size(arr),
              data(Holder<ns::Box>{}));
  return 0;
}
