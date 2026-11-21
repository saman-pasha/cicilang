// THE GNU `cleanup' ATTRIBUTE IN C++ (1.6.8): at every exit of the object's scope, and while an exception unwinds
// through it; with a destructor, the cleanup first and then the destructor, the objects the last declared first; in a
// function template's body and a lambda's; a static member function by its qualified name; [[gnu::cleanup(f)]]
#include <cstdio>
static void bye(int *p) { std::printf("bye %d\n", *p); }
static void thrower(int k) { if (k) throw k; }
static int f(int k) { int a __attribute__((cleanup(bye))) = 10 + k; thrower(k); return a; }
struct R { int id; ~R() { std::printf("~R %d\n", id); } };
static void closeR(R *r) { std::printf("close %d\n", r->id); }
struct S { static void bye(int *p) { std::printf("S::bye %d\n", *p); } };
template <class T> static T twice(T v) { int w __attribute__((cleanup(bye))) = (int)(v * 2); return (T)w; }
static void order() {
    R a{1};
    int b __attribute__((cleanup(bye))) = 2;
    R c __attribute__((cleanup(closeR))) {3};
    R d{4};
    std::printf("body\n");
}
int main() {
    try { std::printf("%d\n", f(0)); std::printf("%d\n", f(1)); } catch (int e) { std::printf("caught %d\n", e); }
    order();
    int t3 = twice(3);
    double t15 = twice(1.5);
    std::printf("%d %g\n", t3, t15);
    auto l = [](int k) { int t __attribute__((cleanup(bye))) = k; return t + 1; };
    std::printf("%d\n", l(4));
    int m __attribute__((cleanup(S::bye))) = 5;
    [[gnu::cleanup(bye)]] int n = 6;
    for (int i = 0; i < 3; i++) { int v __attribute__((cleanup(bye))) = 20 + i; if (i == 1) continue; if (i == 2) break; std::printf("body %d\n", v); }
    { int w __attribute__((cleanup(bye))) = 9; goto out; }
out:
    std::printf("out %d %d\n", m, n);
    return 0;
}
