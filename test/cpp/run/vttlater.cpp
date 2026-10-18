// the VTT (0.172): P : B, virtual PA and Q : virtual PA as the paths of D : P, Q -- a virtual call through the
// shared base in each constructor and destructor reaches the class being built
#include <cstdio>
struct PA { int a = 1; virtual int f() { return 10 + a; } virtual ~PA() {} };
struct B { int b = 2; };
struct P : B, virtual PA {
    int p = 3;
    P() { std::printf("P:%d ", call()); }
    ~P() { std::printf("~P:%d ", call()); }
    int call() { PA *x = this; return x->f(); }
    int f() override { return 30 + p; }
};
struct Q : virtual PA {
    int q = 4;
    Q() { std::printf("Q:%d ", call()); }
    ~Q() { std::printf("~Q:%d ", call()); }
    int call() { PA *x = this; return x->f(); }
};
struct D : P, Q {
    int d = 5;
    D() { std::printf("D:%d ", P::call()); }
    ~D() { std::printf("~D:%d ", Q::call()); }
    int f() override { return 50 + d; }
};
int main() {
    {
        D d;
        std::printf("\n%zu %d %d\n", sizeof(D), d.P::call(), d.Q::call());
    }
    std::printf("\n");
    return 0;
}
