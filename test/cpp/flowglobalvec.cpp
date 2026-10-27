// a function that keeps its parameter in a global vector, handed a local's address: refused (0.217)
#include <vector>
std::vector<int *> g;
void reg(int *p) { g.push_back(p); }
int main() { int x = 1; reg(&x); return g.size() == 1 ? 0 : 1; }
