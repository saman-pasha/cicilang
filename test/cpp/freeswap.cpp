// std::swap of two vectors, one holding a local's address, the other returned: refused (0.217)
#include <utility>
#include <vector>
std::vector<int *> mk() { int x = 1; std::vector<int *> a, b; b.push_back(&x); std::swap(a, b); return a; }
int main() { return mk().size() == 1 ? 0 : 1; }
