// refused: a protected member named through an object of the BASE class from a derived class's member ([class.protected])
#include <cstdio>
struct Base { protected: int secret = 3; };
struct Derived : Base { int peek(Base &b) { return b.secret; } };
int main() { Derived d; Base b; std::printf("%d\n", d.peek(b)); return 0; }
