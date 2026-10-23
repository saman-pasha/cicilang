#include <cstdio>
struct Sq { static int operator()(int x) { return x * x; } static int operator[](int i, int j) { return i * 10 + j; } };
int main() { Sq s; std::printf("%d %d %d\n", Sq{}(3), s[1, 2], Sq::operator()(4)); }
