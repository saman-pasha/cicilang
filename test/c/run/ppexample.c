/* The standard's macro examples (C17 6.10.3.5 EXAMPLES 3, 5 and 7, a part of 4, 6.10.3.3 EXAMPLE), each expansion printed through
   #x: rescanning, a name its own expansion left unexpanded staying so, placemarkers, `##' in an object-like macro and
   from an argument, a character that begins no token, the variadic forms; and what clang and gcc expand where the standard leaves it open (C17 6.10.3.4/4)
   or a hide set decides it. clang's and gcc's output */
#include <stdio.h>
#define S_(...) #__VA_ARGS__
#define XS(...) S_(__VA_ARGS__)
#define str(x) # x
#define x 3
#define f(a) f(x * (a))
#undef x
#define x 2
#define g f
#define z z[0]
#define h g(~
#define m(a) a(w)
#define w 0,1
#define t(a) a
#define p() int
#define q(x) x
#define r(x,y) x ## y
#define LINE1 f(y+1) + f(f(z)) % t(t(g)(0) + t)(1);
#define LINE2 g(x+(3,4)-w) | h 5) & m(f)^m(m);
#define LINE3 p() i[q()] = { q(1), r(2,3), r(4,), r(,5), r(,) };
#define LINE4 char c[2][6] = { str(hello), str() };
#define tt(x,y,z) x ## y ## z
#define LINE5 int j[] = { tt(1,2,3), tt(,4,5), tt(6,,7), tt(8,9,), tt(10,,), tt(,11,), tt(,,12), tt(,,) };
#define debug(...) fprintf(stderr, __VA_ARGS__)
#define showlist(...) puts(#__VA_ARGS__)
#define report(test, ...) ((test)?puts(#test): printf(__VA_ARGS__))
#define LINE6 debug("Flag"); debug("X = %d\n", x); showlist(The first, second, and third items.); report(x>y, "x is %d but y is %d", x, y);
#define hash_hash # ## #
#define mkstr(a) # a
#define in_between(a) mkstr(a)
#define join(c, d) in_between(c hash_hash d)
#define AB a ## b
#define AB2 x ## 1 ## y
#define ff(a) a*gg
#define gg(a) ff(a)
#define NIL(xxx) xxx
#define G_0(arg) NIL(G_1)(arg)
#define G_1(arg) NIL(arg)
#define obj obj+1
#define id(v) v
#define LIT(v) v LIT
#define FN(v) v FN
#define EMPTY()
#define DEFER(v) v EMPTY()
#define A() 123
#define EXP(v) v
#define debug4(s, t) printf("x" # s "= %d, x" # t "= %s", x ## s, x ## t)
int main(void) {
  puts(XS(LINE1));
  puts(XS(LINE2));
  puts(XS(LINE3));
  puts(XS(LINE4));
  puts(XS(LINE5));
  puts(XS(LINE6));
  puts(join(x, y));
  puts(XS(AB AB2));
  puts(XS(ff(2)(9)));
  puts(XS(G_0(42)));
  puts(XS(id(obj) id(id(obj))));
  puts(XS(id(LIT(3))(4) FN(1)(2)));
  puts(XS(DEFER(A)() EXP(DEFER(A)())));
  puts(XS(debug4(1, 2);));
  puts(str(: @\n));
  return 0;
}
