/* #x over expansions and arguments (C17 6.10.3.2/2): an expansion's first token takes the white space before the
   macro's name, an empty expansion and an empty argument pass theirs to the next token, a parameter's own white space
   wins over its argument's, a variadic argument's commas as they stood, a line splice none, a literal spelled with its
   escapes once; clang's and gcc's output */
#include <stdio.h>
#define S(x) #x
#define XS(x) S(x)
#define E
#define EF()
#define M x
#define P1(x) S(<x>)
#define P2(x) S(< x>)
#define G3(x, y, z) S(x y z)
#define G4(x, y) S(x y+)
#define G5(x) a x
#define SV(...) #__VA_ARGS__
#define CAT2(a, b) a ## b
int main(void) {
  puts(XS(a E+b));
  puts(XS(a E +b));
  puts(XS(E a));
  puts(XS(a E));
  puts(XS(a EF()+b));
  puts(XS(+M));
  puts(XS(+ M));
  puts(P1( q));
  puts(P2(q));
  puts(G3(a,,c));
  puts(G4(a,));
  puts(XS(G5()+b));
  puts(SV(a ,b));
  puts(SV(a, b));
  puts(SV(a,b));
  puts(SV( a , b ));
  puts(XS(+ CAT2(x,y)));
  puts(XS(+CAT2(, y)));
  puts(XS(XS(a  b)));
  puts(S( ));
  puts(S(a\
b));
  puts(S(a	b));
  puts(S(a  /*x*/  b));
  puts(S(a
  /* c */ b));
  puts(S("a\tb" '\n' '\'' "\\" "q\"" "\0" '\r' "it's"));
  return 0;
}
