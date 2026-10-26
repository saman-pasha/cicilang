/* #x keeps a space only where white space stood (C17 6.10.3.2/2), and none before the first token or after the last */
#include <stdio.h>
#include <assert.h>
#define S(x) #x
#define XS(x) S(x)
#define PLUS a+b
#define F(x) x + 1
#define G(x) (x)*2
#define CAT(a, b) a ## b
int main(void) {
  puts(S(a+b));
  puts(S(f(1,2)));
  puts(S(  a   +   b  ));
  puts(S(a /* c */ + b));
  puts(S(a/**/b));
  puts(XS(PLUS));
  puts(XS(F(2)));
  puts(XS(G(y+1)));
  puts(XS(CAT(x, y)+z));
  puts(S("x y" 'c'));
  puts(S(a
b));
  puts(S((a,b)));
  puts(S(-1));
  puts(S(x->y.z));
  int a = 1, b = 2;
  assert(a+b == 3);
  return 0;
}
