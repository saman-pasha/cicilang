/* C23's __VA_OPT__ by the standard's examples (C23 6.10.5.1), each expansion printed through #x: the variadic argument
   asked after its expansion (`F(EMP)' is `f(0)'), a group pasted and stringized, placemarkers; clang's and gcc's output */
#include <stdio.h>
#define S_(...) #__VA_ARGS__
#define XS(...) S_(__VA_ARGS__)
#define F(...) f(0 __VA_OPT__(,) __VA_ARGS__)
#define G(X, ...) f(0, X __VA_OPT__(,) __VA_ARGS__)
#define SDEF(sname, ...) S sname __VA_OPT__(= { __VA_ARGS__ })
#define EMP
#define H2(X, Y, ...) __VA_OPT__(X ## Y,) __VA_ARGS__
#define H3(X, ...) #__VA_OPT__(X##X X##X)
#define H4(X, ...) __VA_OPT__(a X ## X) ## b
#define H5A(...) __VA_OPT__()/**/__VA_OPT__()
#define H5B(X) a ## X ## b
#define H5C(X) H5B(X)
int main(void) {
  puts(XS(F(a,b,c)));
  puts(XS(F()));
  puts(XS(F(EMP)));
  puts(XS(G(a,b,c)));
  puts(XS(G(a,)));
  puts(XS(G(a)));
  puts(XS(SDEF(foo);));
  puts(XS(SDEF(bar, 1, 2);));
  puts(XS(H2(a, b, c, d)));
  puts(H3(, 0));
  puts(XS(H4(, 1)));
  puts(XS(H5C(H5A())));
  return 0;
}
