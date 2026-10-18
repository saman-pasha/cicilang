// the VTT (0.172): YZ : YY over YY : Y over Y : B, virtual PA -- a base two levels below its holder is built under
// its own construction tables (Y's constructor reached YY's override over YY's unbuilt member); a cast, a copy
#include <cstdio>
struct PA { int a = 1; PA() { std::printf("PA "); } virtual int fa() { return 10 + a; } virtual ~PA() { std::printf("~PA "); } };
struct B { int b = 2; B() { std::printf("B "); } ~B() { std::printf("~B "); } };
struct Y : B, virtual PA { int y = 3; Y() { std::printf("Y:%d ", fa()); } int fa() override { return 30 + y; } ~Y() { std::printf("~Y "); } };
struct YY : Y { int yy = 4; YY() { std::printf("YY:%d ", fa()); } int fa() override { return 40 + yy; } ~YY() { std::printf("~YY "); } };
struct YZ : YY { int yz = 5; };
static long off(const void *p, const void *b) { return (const char *) p - (const char *) b; }
int main() {
    {
        YY o;
        std::printf("\n%zu %zu %d %d %d %d\n", sizeof(Y), sizeof(YY), o.a, o.b, o.y, o.yy);
        PA *pa = &o; Y *py = &o; B *pb = &o;
        std::printf("%d %d %ld %ld %ld %ld\n", pa->fa(), py->fa(), off(pa, &o), off(py, &o), off(pb, &o), off(&o.yy, &o));
        std::printf("%d %d\n", dynamic_cast<YY *>(pa) == &o, dynamic_cast<Y *>(pa) == py);
        YY c = o;
        c.a = 9;
        std::printf("%d %d %d\n", c.a, o.a, static_cast<PA &>(c).fa());
    }
    std::printf("\n");
    {
        YZ z;
        PA *pa = &z;
        std::printf("\n%zu %d %ld %ld\n", sizeof(YZ), pa->fa(), off(pa, &z), off(&z.yz, &z));
    }
    std::printf("\n");
    return 0;
}
