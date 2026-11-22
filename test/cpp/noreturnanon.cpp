// A RETURN OF AN ANONYMOUS NAMESPACE'S [[noreturn]] FUNCTION (1.6.17), named as clang++ names it
#include <cstdlib>
namespace { [[noreturn]] void stop(int x) { if (x) return; std::exit(1); } }
int main() { stop(0); }
