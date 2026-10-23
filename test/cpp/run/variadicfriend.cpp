#include <cstdio>
template <class... Ts> class Fr { friend Ts...; int secret = 42; };
struct U1 { int get(Fr<U1> &f) { return f.secret; } };
int main() { Fr<U1> fr; U1 u; std::printf("%d\n", u.get(fr)); }
