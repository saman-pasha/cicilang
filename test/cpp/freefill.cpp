// std::fill of a vector with a local's address, the vector returned: refused (0.217)
#include <algorithm>
#include <vector>
std::vector<int *> mk() { int x = 1; std::vector<int *> v(2); std::fill(v.begin(), v.end(), &x); return v; }
int main() { return mk().size() == 2 ? 0 : 1; }
