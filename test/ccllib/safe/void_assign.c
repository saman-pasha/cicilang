/* 1.6.14: a void value assigned over an object that its scope drops is refused -- as C by its type macro, which makes an
 * instance of no value of the type void, and as C++ in clang++'s words, `no viable overloaded '=''; through 1.6.13 C++'s
 * `none' went on to the store after the old value's drop */
#include <vector.pl>
void f(void) {}
int main(void) {
    vector<int> v = {};
    v = f();
    return 0;
}
