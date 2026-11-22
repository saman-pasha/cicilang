// A FUNCTION THAT JUMPS OUT OF ITS FRAME WITH A LOCAL THAT HAS A DESTRUCTOR (1.6.17): refused in the function
#include <csetjmp>
#include <cstdio>
static std::jmp_buf env;
struct Loud { int v; ~Loud() { std::printf("~Loud %d\n", v); } };
static void jump() { Loud l{2}; std::longjmp(env, 1); }
int main() { if (setjmp(env)) return 0; jump(); return 1; }
