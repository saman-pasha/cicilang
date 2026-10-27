// a local's address stored in the caller's vector through a reference: refused (borrow_stored, 0.216)
#include <vector>
struct S { std::vector<int *> v; };
void put(S &s) { int x = 1; s.v.push_back(&x); }
int main() { S s; put(s); return s.v.size() == 1 ? 0 : 1; }
