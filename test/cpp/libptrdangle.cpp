// a pointer to a vector of pointers used after the vector ended: refused (0.217)
#include <vector>
int main() { int x = 1; std::vector<int *> *pv = nullptr; { std::vector<int *> v{&x}; pv = &v; } return (int) pv->size() - 1; }
