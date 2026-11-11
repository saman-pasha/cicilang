/* OPERATORS WHOSE LEFT OPERAND IS NO INSTANCE (0.291): `"abc" == t' is the instance's own relation with the operands
   exchanged, `t_eq_ptr_const_char(&t, "abc")', `"abd" > t' is `t < "abd"', and `"<" + t' is the function named `r' and
   the operator's word, `_radd_ptr_const_char("<", &t)'; `t > "abb"' and `t <= "abc"' take the typed `_gt' first. Until
   0.291 the reader refused each: `the operator == of tag_char takes the object on its left'. This file is C and C++:
   cicilang++ builds it too, and it prints what clang's build of its hand expansion prints */
#include <stdio.h>
#include <string.h>
#include "tmirror.pl"
int main(void) {
    tag<char> t = "abc";
    printf("%d %d %d %d %d %d\n", "abc" == t, "abc" != t, "abb" < t, "abd" > t, "abc" <= t, "abb" >= t);
    printf("%d %d %d %d %d %d\n", t == "abc", t != "abc", t < "abd", t > "abb", t <= "abc", t >= "abd");
    tag<char> u = "<" + t;
    tag<char> v = u + ">";
    tag<char> w = '(' + v;
    printf("%s %s %s\n", u.s, v.s, w.s);
    return 0;
}
