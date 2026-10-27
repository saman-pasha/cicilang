// a vector given the addresses of two locals, used after the inner one ended: refused (0.217; it kept the first)
#include <vector>
int main() { int a = 1; std::vector<int *> v; { int b = 2; v.push_back(&a); v.push_back(&b); } return *v[0] - 1; }
