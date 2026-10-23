// -fno-rtti (0.191): libc++ leaves std::dynamic_pointer_cast unguarded in its no-RTTI configuration, and its dynamic_cast is
// refused where a program calls it, as clang++ -fno-rtti refuses it ("use of dynamic_cast requires -frtti")
#include <memory>
struct B { virtual ~B() {} };
struct D : B { int d = 2; };
int main() { std::shared_ptr<B> sb = std::make_shared<D>(); return std::dynamic_pointer_cast<D>(sb) ? 0 : 1; }
