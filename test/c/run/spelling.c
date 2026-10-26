#include <stdio.h>
/* a token's spelling in #x (C17 6.10.3.2/2: "the spelling of the preprocessing token"): a literal as written, its
   escapes and its prefix kept, a digraph as written, a name past ASCII in UTF-8; 0.210 spelled the token's value */
#define S(...) #__VA_ARGS__
#define XS(...) S(__VA_ARGS__)
#define LIT "\x41\101\n" '\4'
#define CAT(a, b) a ## b
#define HH %: %:%: %:
#define MK(a) %: a
#define IN(a) MK(a)
#define JOIN(c, d) IN(c HH d)
#define DGCAT(a, b) a %:%: b
int main(void) {
  puts(S("\x41" "\101" '\4' '\'' "\u00e9" "é" "\\" "\""));
  puts(S(L"\x41" u"\x42" U'\U0001F600' u8"\x43" 'ab' L'\0'));
  puts(S(<: :> <% %> %: %:%:));
  puts(JOIN(x, y));
  puts(S(café "café" 'é'));
  puts(XS(LIT));
  puts(XS(S(LIT)));
  puts(S(0x1p3 1e+5 .5f 08));
  puts(S(a\
b "c\
d"));
  int a<:2:> = <% 4, 2 %>;
  printf("%d %d %d %d\n", CAT(1, 2), DGCAT(3, 4), a<:0:>, a[1]);
#line 100 "café.c"
  printf("%s %d\n", __FILE__, __LINE__);
  return 0;
}
