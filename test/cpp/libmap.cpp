// a map given a local's address through operator[] leaves the function: refused (borrow_escapes, 0.216)
#include <map>
std::map<int, int *> mk() { int x = 1; std::map<int, int *> m; m[3] = &x; return m; }
int main() { return mk().size() == 1 ? 0 : 1; }
