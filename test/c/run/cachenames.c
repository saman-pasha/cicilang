/* A typedef, a tag and a function's types named `names' (0.194): the named caches kept their index under the
   prefix and `names', the global of the name `names' too, and its second ask answered the index, a list of names. */
#include <stdio.h>
typedef int names;
struct names { int a; };
names f(names x) { return x + 1; }
names g(names x) { return x * 2; }
int main(void) {
    names a = 3; struct names s = { 4 }; names b = g(a);
    printf("%d %d %d %zu\n", f(a), s.a, b, sizeof(names));
    return 0;
}
