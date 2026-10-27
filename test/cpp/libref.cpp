// a reference_wrapper of a local leaves the function: refused (borrow_escapes, 0.216)
#include <functional>
std::reference_wrapper<int> r() { int x = 7; return std::ref(x); }
int main() { return r().get() == 7 ? 0 : 1; }
