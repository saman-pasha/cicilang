// A NAMESPACE'S FUNCTION THAT KEEPS ITS PARAMETER IN A GLOBAL VECTOR, HANDED A LOCAL'S ADDRESS (1.6.16): its flow is known,
// as a function's at file scope is (0.217, flowglobalvec.cpp), and the borrow stored is refused
#include <vector>
namespace reg {
std::vector<int *> g;
void add(int *p) { g.push_back(p); }
}
int main() { int x = 1; reg::add(&x); return reg::g.size() == 1 ? 0 : 1; }
