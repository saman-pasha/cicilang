#include <memory>
struct S { std::unique_ptr<int> p; };
int main() { S a; S b = a; return b.p ? 1 : 0; }
