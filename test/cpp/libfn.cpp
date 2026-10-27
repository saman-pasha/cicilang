// a std::function holding a closure over a local leaves the function: refused (borrow_escapes, 0.216)
#include <functional>
std::function<int()> g() { int x = 5; return [&x] { return x; }; }
int main() { return g()() == 5 ? 0 : 1; }
