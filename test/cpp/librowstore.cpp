// a local's address stored through the range-for's reference into a local nested vector, returned: refused (0.217)
#include <vector>
std::vector<std::vector<int *>> f() { int b = 2; std::vector<std::vector<int *>> g(2); for (auto &row : g) row.push_back(&b); return g; }
int main() { return f().size() == 2 ? 0 : 1; }
