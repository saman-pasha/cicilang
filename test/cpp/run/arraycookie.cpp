#include <cstdio>
static int made = 0, gone = 0;
struct T { int v; T() : v(++made) {} T(int x) : v(x) { ++made; } ~T() { ++gone; std::printf("~%d ", v); } };
struct P { int a; P() : a(7) {} };
int main() {
    T *arr = new T[3];
    std::printf("%d %d %d\n", arr[0].v, arr[1].v, arr[2].v);
    delete[] arr;
    std::printf("\n%d %d\n", made, gone);
    T *b = new T[4]{10, 20};
    std::printf("%d %d %d %d\n", b[0].v, b[1].v, b[2].v, b[3].v);
    delete[] b;
    std::printf("\n");
    P *p = new P[2];
    std::printf("%d %d\n", p[0].a, p[1].a);
    delete[] p;
    int *q = new int[3]{1, 2};
    std::printf("%d %d %d\n", q[0], q[1], q[2]);
    delete[] q;
    int n = 2; T *c = new T[n];
    delete[] c;
    std::printf("\n%d %d\n", made, gone);
    return 0;
}
