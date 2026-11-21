/* C23's spelling of the GNU `cleanup' attribute (1.6.8): [[gnu::cleanup(f)]] before the declaration, each declarator's,
   and after a declarator, its own */
#include <stdio.h>
static void bye(int *p) { printf("bye %d\n", *p); }
int main(void) {
    [[gnu::cleanup(bye)]] int a = 1, b = 2;
    int c [[gnu::cleanup(bye)]] = 3, d = 4;
    int e [[__gnu__::__cleanup__(bye)]] = 5;
    printf("%d %d %d %d %d\n", a, b, c, d, e);
    return 0;
}
