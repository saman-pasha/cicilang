/* a _BitInt past BITINT_MAXWIDTH, 8388608 on x86-64, its width an enumerator, refused in clang's words (1.6.57) */
enum { W = 8388609 };
typedef _BitInt(W) huge;
int main(void) { return 0; }
