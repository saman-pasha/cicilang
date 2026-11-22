// THE END OF A NOEXCEPT [[noreturn]] FUNCTION THAT A PATH REACHES (1.6.17), refused at the line of its body's last
// statement -- the noexcept guard that the desugaring puts around the body stands at the function's line
#include <cstdlib>
[[noreturn]] void stop(int c) noexcept {
    if (c)
        std::exit(2);
}
int main() { stop(1); }
