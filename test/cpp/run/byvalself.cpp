// a class prvalue handed to a by-value parameter IS the parameter ([class.copy.elision]/1): a class that holds its own address
#include <cstdio>
#include <functional>
#include <list>
#include <map>
#include <string>
int sum(std::list<int> l) { int s = 0; for (int x : l) s += x; return s; }
int msum(std::map<int, int> m) { int s = 0; for (auto &kv : m) s += kv.first * kv.second; return s; }
int call(std::function<int(int)> f, int x) { return f(x); }
std::list<int> mk() { return std::list<int>{4, 5, 6}; }
int main() {
    std::printf("%d\n", sum(std::list<int>{1, 2, 3}));
    std::printf("%d\n", sum(mk()));
    std::list<int> l{7, 8};
    std::printf("%d\n", sum(l));
    std::printf("%d\n", msum(std::map<int, int>{{1, 2}, {3, 4}}));
    int k = 3;
    std::printf("%d\n", call([k](int x) { return x * k; }, 5));
    std::function<int(int)> g = [k](int x) { return x + k; };
    std::printf("%d\n", call(g, 6));
}
