// a pointer less a call whose result is `auto', added to a pointer: libc++ 22's `__to_buffer' writes
// `auto __diff = __r.ptr - std::to_address(__first); return __first + __diff;' (<format>, <chrono>), whose `__diff' the
// reader types as the pointer; 1.6.1's operand rule, asked in C++ too, refused `__first + __diff' -- C's alone now
#include <cstdio>
template <class T> auto id(T *p) { return p; }
int main() {
    char buf[8];
    char *f = buf, *l = buf + 5;
    auto d = l - id(f);
    char *g = f + d;
    std::printf("%d %d\n", (int)d, (int)(g - buf));
    return 0;
}
