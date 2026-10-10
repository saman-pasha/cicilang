// refused: a public member of a PRIVATE base is a private member of the derived class ([class.access.base]/1)
#include <cstdio>
struct Base { int pub() const { return 1; } };
class Derived : private Base { public: int mine() const { return pub() + 1; } };
int main() { Derived d; std::printf("%d %d\n", d.mine(), d.pub()); return 0; }
