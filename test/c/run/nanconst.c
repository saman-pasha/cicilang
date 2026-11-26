/* a NaN converted to an integer type in a constant (1.6.24): the conversion is undefined (C17 6.3.1.4/1), and clang's
   fold makes it 0, as gcc's does, a _Bool's 1 -- `int n = (int)(0.0 / 0.0);' at file scope was refused, `global_init',
   since the fold kept no value for it; a NaN converted to a floating type stays a NaN */
#include <stdio.h>
int n = (int)(0.0 / 0.0);
unsigned u = (unsigned)(0.0 / 0.0);
long long ll = (long long)(-(0.0 / 0.0));
_Bool b = (_Bool)(0.0 / 0.0);
short sh = (short)(0.0 / 0.0);
double back = (double)(int)(0.0 / 0.0);
int main(void) { printf("%d %u %lld %d %d %f\n", n, u, ll, b, sh, back); return 0; }
