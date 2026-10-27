// a function that keeps its parameter in a static local vector, handed a local's address through another function: refused (0.217)
#include <vector>
std::size_t reg(int *p) { static std::vector<int *> all; all.push_back(p); return all.size(); }
std::size_t fwd(int *p) { return reg(p); }
int main() { int x = 1; return fwd(&x) == 1 ? 0 : 1; }
