// refused: a local of a class whose destructor is private ([class.dtor]/15, [class.access]/4)
#include <cstdio>
class Handle { ~Handle() {} public: int v = 2; static Handle *make() { return new Handle; } void drop() { delete this; } };
int main() { Handle h; std::printf("%d\n", h.v); return 0; }
