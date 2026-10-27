// a vector parameter by value given a local's address and returned: refused (borrow_escapes, 0.216)
#include <vector>
std::vector<int *> add(std::vector<int *> v) { int x = 4; v.push_back(&x); return v; }
int main() { return add({}).size() == 1 ? 0 : 1; }
