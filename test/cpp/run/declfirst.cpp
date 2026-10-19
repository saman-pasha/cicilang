// A DEFINITION AFTER A DECLARED OVERLOAD OF OTHER PARAMETERS (0.181): the name had one definition and kept its plain
// name, and the table holds one type a name, the first declared, so each call below took the declaration's parameters:
// the literal's address for `const Inc &', a pointer converted to a double, one argument for two
#include <cstdio>
struct Inc;
int g(const Inc &);
int g(const char *s) { return s[0]; }
int h(double);
int h(const char *s) { return s[1]; }
int k(int);
int k(int a, int b) { return a * b; }
int m(long);
int m(int x) { return x + 1; }
int (*pm)(int) = m;
int main() {
    std::printf("%d %d %d %d %d\n", g("abc"), h("xyz"), k(6, 7), m(3), pm(9));
    return 0;
}
