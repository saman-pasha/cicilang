// a function of the program stores its pointer parameter moved within the array, `p + 1', in a vector it takes by reference;
// the caller's vector returned: refused (0.221)
#include <vector>
void put(std::vector<int *> &out, int *p) { out.push_back(p + 1); }
std::vector<int *> mk() { int a[2] = {1, 2}; std::vector<int *> out; put(out, a); return out; }
int main() { return mk().size() == 1 ? 0 : 1; }
