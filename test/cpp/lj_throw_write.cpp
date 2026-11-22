// A POINTER STEPPED BEFORE A THROW THAT A HANDLER CATCHES, AND THE HANDLER'S LONGJMP (1.6.17): the block that throws ends
// its path, but the handler goes on from the throw, so the step is kept and the jump refused
#include <csetjmp>
#include <cstdio>
static std::jmp_buf env;
int main() {
    const char *text = "abc";
    const char *s = text;
    if (setjmp(env)) { std::printf("%c\n", *s); return 0; }
    try { { s++; throw 1; } } catch (int) { std::longjmp(env, 1); }
    return 0;
}
