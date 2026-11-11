// the twin of first.c over std:: (0.273): clang++ builds it over libc++, and what it prints is first.expect
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <utility>
#include <vector>
static long sum(std::vector<int> v) {
    long s = 0;
    for (size_t i = 0; i < v.size(); i++) s += v.at(i);
    return s;
}
static int many(long n) {
    std::vector<int> v;
    unsigned x = 12345;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) { x = x * 1103515245u + 12345u; v.push_back((int)(x >> 8)); }
    std::sort(v.begin(), v.end());
    long s = 0;
    for (size_t i = 0; i < v.size(); i += 1 + v.size() / 16) s += v.at(i);
    std::printf("%zu %d %d %ld\n", v.size(), v.at(0), v.at(v.size() - 1), s);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(std::atol(argv[1]));
    std::vector<int> v = {5, 3, 9};
    v.push_back(1);
    v.push_back(7);
    for (int i = 0; i < 20; i++) v.push_back((i * 37 + 11) % 23);
    std::printf("%zu %d %d\n", v.size(), v.at(0), v.at(4));
    std::sort(v.begin(), v.end());
    for (size_t i = 0; i < v.size(); i++) std::printf("%d ", v.at(i));
    std::printf("\n");
    std::vector<double> w = {2.5, -1, 0.25};
    std::sort(w.begin(), w.end());
    std::printf("%g %g %g %zu\n", w.at(0), w.at(1), w.at(2), w.size());
    std::printf("%ld\n", sum(std::move(v)));
    return 0;
}
