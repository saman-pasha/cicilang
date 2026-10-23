// -fno-rtti (0.191): a downcasting dynamic_cast is refused, as clang++ -fno-rtti refuses it ("use of dynamic_cast requires -frtti")
struct B { virtual ~B() {} };
struct D : B {};
int main() { D d; B *b = &d; return dynamic_cast<D *>(b) ? 0 : 1; }
