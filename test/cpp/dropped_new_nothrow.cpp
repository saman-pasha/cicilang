// NEW MEMORY THROWN AWAY (0.309): the nothrow form of the library's operator new, as a statement, leaks its block,
// refused as new is
#include <new>
int main() {
    new (std::nothrow) int(3);
    return 0;
}
