// refused: a private nested type named outside its class ([class.access]/4)
#include <cstdio>
class Outer { struct Secret { int v = 7; }; public: int get() const { return Secret{}.v; } };
int main() { Outer::Secret s; std::printf("%d\n", s.v); return 0; }
