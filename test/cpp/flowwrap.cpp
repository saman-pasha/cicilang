// a member that stores through another member; the object, given a local's address, returned: refused (0.217)
#include <vector>
struct Registry { std::vector<int *> items; void add(int *w) { items.push_back(w); } void add2(int *w) { add(w); } };
Registry mk() { int w = 1; Registry r; r.add2(&w); return r; }
int main() { return mk().items.size() == 1 ? 0 : 1; }
