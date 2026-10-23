// A stream whose exceptions mask holds failbit throws std::ios_base::failure where a read fails (0.193): libc++'s
// compiled library throws it, through the program's frames, to the program's handler
#include <cstdio>
#include <sstream>

int main() {
    std::istringstream in("12 x");
    in.exceptions(std::ios::failbit);
    int a = 0, b = 0;
    try {
        in >> a >> b;
        std::printf("no failure\n");
    } catch (const std::ios_base::failure &) {
        std::printf("failure %d %d\n", a, (int) in.fail());
    }
    return 0;
}
