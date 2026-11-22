// A LONGJMP OVER A LOCAL WITH A DESTRUCTOR (1.6.17; [csetjmp.syn]/4: undefined where a destructor is skipped) -- refused at
// the call of the function that jumps
#include <csetjmp>
#include <cstdio>
static std::jmp_buf env;
struct Loud { int v; ~Loud() { std::printf("~Loud %d\n", v); } };
static void jump() { std::longjmp(env, 1); }
int main() { if (setjmp(env)) return 0; Loud l{1}; jump(); return 1; }
