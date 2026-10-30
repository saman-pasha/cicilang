// AN UNQUALIFIED USE IN A NESTED NAMESPACE FINDS THE INNERMOST ENCLOSING NAMESPACE'S NAME (0.233; [basic.lookup.unqual]/4):
// a function and a class that two of the program's namespaces and the global one declare, used bare inside b::c and
// b::c::d, are b's; a local of the name shadows it
#include <cstdio>
namespace a { int helper(long) { return 1; } struct Box { int v = 10; }; int call() { return helper(5) + Box{}.v; } }
namespace b {
int helper(int) { return 2; }
struct Box { int v = 20; };
int call() { return helper(5) + Box{}.v; }
namespace c {
int call() { return helper(5) + Box{}.v; }
namespace d { int call() { return helper(5) + Box{}.v; } }
int shadow() { int helper = 7; return helper; }
}
}
int helper(double) { return 3; }
struct Box { int v = 30; };
int main() {
  std::printf("%d %d %d %d %d %d\n", a::call(), b::call(), b::c::call(), b::c::d::call(), b::c::shadow(), helper(5) + Box{}.v);
  return 0;
}
