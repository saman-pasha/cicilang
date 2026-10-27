// std::copy into a back inserter, from a vector holding a local's address, the destination returned: refused (0.217)
#include <algorithm>
#include <iterator>
#include <vector>
std::vector<int *> mk() { int x = 1; std::vector<int *> src{&x}, dst; std::copy(src.begin(), src.end(), std::back_inserter(dst)); return dst; }
int main() { return mk().size() == 1 ? 0 : 1; }
