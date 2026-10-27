// a struct whose vector member holds a local's address leaves the function: refused (borrow_escapes, 0.216)
#include <vector>
struct S { std::vector<int *> v; };
S mk() { int x = 1; S s; s.v.push_back(&x); return s; }
int main() { return mk().v.size() == 1 ? 0 : 1; }
