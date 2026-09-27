#include <cstdio>
struct Pt { int x; double y; int z; };
struct Big : Pt { int w; };
int main() {
    Pt p{3, 2.5, 9};
    int Pt::*px = &Pt::x;
    int Pt::*pz = &Pt::z;
    double Pt::*py = &Pt::y;
    Pt *q = &p;
    q->*pz = 11;
    Big b{{1, 1.0, 2}, 4};
    printf("%d %d %.1f %d %d %d\n", p.*px, p.*pz, p.*py, q->*px, b.*pz, (int) sizeof(px));
    return 0;
}
