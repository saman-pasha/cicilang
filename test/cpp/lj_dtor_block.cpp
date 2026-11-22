// A LONGJMP OUT OF A BLOCK WITH A LOCAL THAT HAS A DESTRUCTOR (1.6.17): the block is left with no destructor run -- refused
#include <csetjmp>
#include <cstdio>
static std::jmp_buf env;
struct Loud { int v; ~Loud() { std::printf("~Loud %d\n", v); } };
static void jump() { std::longjmp(env, 1); }
int main() { if (setjmp(env)) return 0; { Loud l{1}; jump(); } return 1; }
