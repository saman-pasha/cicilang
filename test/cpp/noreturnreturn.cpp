// A RETURN OF A NAMESPACE'S FUNCTION DECLARED [[noreturn]] (1.6.17), refused at its line in clang++'s words, the function
// named as clang++ names it, without its scope
#include <cstdlib>
namespace app {
[[noreturn]] void stop(int x) {
    if (x) return;
    std::exit(1);
}
}
int main() { app::stop(0); }
