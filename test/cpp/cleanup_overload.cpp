// GCC's cleanup attribute in C++ names one function (1.6.8): a name of two overloads is refused in clang's words
#include <cstdio>
static void bye(int *p) { std::printf("bye int %d\n", *p); }
static void bye(double *p) { std::printf("bye double %g\n", *p); }
int main() { int i __attribute__((cleanup(bye))) = 7; std::printf("%d\n", i); return 0; }
