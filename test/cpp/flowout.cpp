// a local's address handed to a member that stores it, the object the caller's through a reference: refused (0.217)
#include <vector>
struct Registry { std::vector<int *> items; void add(int *w) { items.push_back(w); } };
void fill(Registry &r) { int w = 1; r.add(&w); }
int main() { Registry r; fill(r); return 0; }
