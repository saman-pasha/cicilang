// A RETURN OF AN OVERLOADED [[noreturn]] FUNCTION (1.6.17), refused at its line in clang++'s words, the function named as
// clang++ names it, without its parameters' keys
#include <cstdlib>
[[noreturn]] void stop(int x) {
    if (x) return;
    std::exit(1);
}
void stop(double) { }
int main() { stop(0); }
