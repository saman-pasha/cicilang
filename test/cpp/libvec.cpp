// a vector given a local's address leaves the function: refused by the safe part (borrow_escapes, 0.216)
#include <vector>
std::vector<int *> f() { int x = 5; std::vector<int *> v; v.push_back(&x); return v; }
int main() { return f().size() == 1 ? 0 : 1; }
