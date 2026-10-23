// C++17's order of evaluation ([expr.ass]/1, [expr.shift]/4, [expr.call]/8, [expr.ref]/1)
#include <cstdio>
#include <map>
#include <iostream>
#include <string>
#include <vector>
static int n = 0;
int next() { return ++n; }
struct S { int v = 0; S &set(int x) { v = v * 10 + x; return *this; } };
int main() {
    std::map<int, int> m;
    m[next()] = next();
    for (auto &kv : m) std::printf("%d %d\n", kv.first, kv.second);
    int a[3] = {0, 0, 0}; int i = 0;
    a[i] = i = 2;
    std::printf("%d %d %d\n", a[0], a[1], a[2]);
    n = 0; S s; s.set(next()).set(next()).set(next());
    std::printf("%d\n", s.v);
    n = 0; int x = next() << next();
    std::printf("%d\n", x);
    n = 0; auto f = [](int p) { return [p](int q) { return p * 10 + q; }; };
    std::printf("%d\n", f(next())(next()));
    n = 0; std::cout << next() << " " << next() << "\n";
    n = 0; int b[4] = {0, 0, 0, 0}; int *p = b; *p++ = next(); *p++ = next();
    std::printf("%d %d %d\n", b[0], b[1], (int) (p - b));
    n = 0; int k = 0; k += next() * 10; k += next();
    std::printf("%d\n", k);
    n = 0; n += next(); int after = n;
    std::printf("%d\n", after);
    n = 0; std::vector<std::string> vs(4); vs[next()] = std::to_string(next());
    std::printf("[%s] [%s] [%s]\n", vs[1].c_str(), vs[2].c_str(), vs[3].c_str());
    n = 0; std::map<int, std::string> ms; ms[next()] = std::to_string(ms.size());
    std::printf("%zu %s\n", ms.size(), ms.begin()->second.c_str());
}
