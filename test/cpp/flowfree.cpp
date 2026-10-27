// a function of the program stores its pointer parameter in a vector it takes by reference; the caller's vector returned: refused (0.217)
#include <vector>
void put(std::vector<int *> &v, int *p) { v.push_back(p); }
std::vector<int *> mk() { int x = 1; std::vector<int *> v; put(v, &x); return v; }
int main() { return mk().size() == 1 ? 0 : 1; }
