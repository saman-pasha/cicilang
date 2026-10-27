// a member of the program's class stores its parameter in the object's vector; the object, given a local's address, returned: refused (0.217)
#include <vector>
struct Registry { std::vector<int *> items; void add(int *w) { items.push_back(w); } };
Registry mk() { int w = 1; Registry r; r.add(&w); return r; }
int main() { return mk().items.size() == 1 ? 0 : 1; }
