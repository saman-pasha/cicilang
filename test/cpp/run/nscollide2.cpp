// A colliding name inside a BASE CLAUSE of the deeper namespace (0.100's not-done): 'struct D : Base' inside
// outer::inner names inner's Base, and a default argument there names inner's pick.
#include <cstdio>
namespace outer {
    struct Base { int v = 7; };
    int pick(int x = 1) { return x; }
    namespace inner {
        struct Base { int v = 40; };
        int pick(int x = 2) { return x * 100; }
        struct D : Base { int w = 3; };
        int call(int k = pick()) { return k; }
    }
}
int main() {
    outer::inner::D d;
    printf("%d %d %d %d\n", d.v, d.w, outer::inner::call(), outer::pick());
    return 0;
}
