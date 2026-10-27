// an iterator into a vector of pointers used after the vector ended: refused (0.217; until then the iterator borrowed what the vector held)
#include <vector>
int main() { int x = 1; std::vector<int *>::iterator it; { std::vector<int *> v{&x}; it = v.begin(); } return **it - 1; }
