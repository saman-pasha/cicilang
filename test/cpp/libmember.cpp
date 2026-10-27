// a local's address stored in a member of the object: refused (borrow_stored, 0.216)
#include <vector>
struct Keep {
  std::vector<int *> v;
  void add() { int x = 1; v.push_back(&x); }
};
int main() { Keep k; k.add(); return k.v.size() == 1 ? 0 : 1; }
