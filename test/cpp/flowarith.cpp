// a function of the program stores a place in its pointer parameter's pointee, `&p->v', in a vector it takes by reference; the
// caller's vector returned: refused (0.221)
#include <vector>
struct S { int v; };
void put(std::vector<int *> &out, S *p) { out.push_back(&p->v); }
std::vector<int *> mk() { S s{1}; std::vector<int *> out; put(out, &s); return out; }
int main() { return mk().size() == 1 ? 0 : 1; }
