// AN #include INSIDE AN ITEM IN C++ (0.310): after a function's definition, a prototype and an array's bound it is a
// header's #include, a library header read as one; in the braces of a linkage specification, after a declaration, it is
// a header's #include too, a library's C++ header among them; in a namespace's braces it is its file's text in place, as
// clang++ has it -- the names of inplace_ns.h, whose own #include of <cstddef> its guard passes over, are the
// namespace's. Over 0.309 the namespace's form was `not lowered yet: typedef(scoped([std],size_t))'; a library header's
// text in place is `syntax error'
#include <cstddef>
static int g() { return 1; }
int f(int);
int h[2];
#include <cstdio>
int x0;
extern "C++" {
#include <vector>
}
namespace ns {
#include "inplace_ns.h"
}
int f(int x) { return x + g() + h[1]; }
int main() {
    std::vector<int> v{1, 2};
    std::printf("%d %d %d\n", v[1] + x0, (int)ns::size3(), f(1));
    return 0;
}
