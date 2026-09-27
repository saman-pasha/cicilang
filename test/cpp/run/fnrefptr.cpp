// A function bound to a reference to a POINTER converts first and the reference binds the temporary pointer
// ([conv.func], [dcl.init.ref]/5): libc++'s __tuple_leaf(_Tp &&) over int (*const &)(int, int, int), which is how
// std::bind_front stores its callee; handed the function's own address as the pointer's, it jumped into the code.
#include <cstdio>
int twice(int x) { return 2 * x; }
struct Leaf {
    int (*f)(int);
    template <class T> Leaf(T &&t) : f(t) {}
};
int take(int (*const &pf)(int), int x) { return pf(x); }
template <class F> int fwd(F &&f, int x) { return take(f, x); }
int main() {
    Leaf l(twice);
    printf("%d %d %d\n", l.f(3), take(twice, 4), fwd(twice, 5));
    return 0;
}
