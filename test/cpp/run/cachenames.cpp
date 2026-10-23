// A class, an alias, a function's result and a namespace's variable named `names' (0.194): the named caches kept
// their index under the prefix and `names', the global of the name `names' too, and its second ask answered the index
// -- the class's type was `[names]'
#include <cstdio>
struct names { int a; int get() const { return a; } };
typedef names alias;
using cnt = int;
names make(int k) { return names{k}; }
namespace n { int names = 5; }
int main() {
    names x{4}; alias y{6}; names z = make(7); cnt c = 2;
    std::printf("%d %d %d %d %d %zu\n", x.get(), y.get(), z.get(), n::names, c, sizeof(names));
    return 0;
}
