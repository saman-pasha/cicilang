// an iterator into a local vector leaves the function: refused (borrow_escapes, 0.216)
#include <vector>
std::vector<int>::iterator first() { std::vector<int> v{1, 2, 3}; return v.begin(); }
int main() { first(); return 0; }
