/* NAMES DECLARED AGAIN THAT C TAKES (0.298; beside the refusal of a name declared again at file scope as another kind of
   symbol): compatible declarations of one function and of one object, a tentative definition before its definition, a
   block's object, a parameter and a member named as a file scope's function or object, a block's typedef named as a
   later function, and a typedef declared twice as the same type. Each line is clang's */
#include <stdio.h>
int f(int);
int f(int x) { return x * 2; }
extern int x;
int x = 5;
static int y;
static int y = 3;
int g(void);
int g(void) { return f(x) + y; }
int t(void) { return 3; }
static const unsigned tab[3] = { 7, 8, 9 };
static unsigned u(unsigned i) { return tab[i]; }
struct s { int f; int g; };
static int h(int f) { return f + 1; }
static void blk(void) { typedef int bt; bt v = 1; printf("%d ", v); }
static int bt(void) { return 2; }
typedef int same;
typedef int same;
int main(void) {
    int t = 4;
    struct s v = { 3, 4 };
    same w = 6;
    blk();
    { double t = 1.5; printf("%.1f ", t); }
    int tab = 2;
    printf("%d %d %d %d %u %d %d %d %d\n", g(), t, f(1), h(5), u(1), v.f + v.g, tab, bt(), w);
    return 0;
}
