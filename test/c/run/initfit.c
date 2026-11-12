/* Initializers that fill their objects to the bound and no further (0.302): each form here went wrong before -- a
   string literal in braces gave the array its address, a literal that fills its array exactly wrote its terminator
   past it, a designator that is no plain number took the cursor's place, and a scalar global's braced value was
   refused. clang builds this file with one warning, of the braces around a scalar's value, and both print the same
   lines */
#include <stdio.h>
#include <wchar.h>
struct name { char text[3]; };
struct tag { char text[4]; int n; };
static char exact_global[3] = "abc";
static char braced_global[4] = {"xyz"};
static int braced_scalar = {5};
static struct { int a[2]; int b; } nested_scalar = {{1, 2}, {3}};
static int designated_global[4] = {[1 + 1] = 7, [3] = 8};
int main(void) {
    char braced[4] = {"abc"};
    char braced_exact[3] = {"abc"};
    char exact[2] = "ab";
    char joined[3] = "ab" "c";
    wchar_t wide[3] = L"xyz";
    int designated[4] = {[1 + 1] = 5};
    int scalar = {9};
    struct name n = {"abc"};
    struct tag t = {"abc", 7};
    printf("%s %c%c%c %c%c %c%c%c\n", braced, braced_exact[0], braced_exact[1], braced_exact[2], exact[0], exact[1], joined[0], joined[1], joined[2]);
    printf("%lc%lc%lc %d %d %d %d %d\n", (wint_t)wide[0], (wint_t)wide[1], (wint_t)wide[2], designated[0], designated[1], designated[2], designated[3], scalar);
    printf("%c%c%c %s %d\n", n.text[0], n.text[1], n.text[2], t.text, t.n);
    printf("%c%c%c %s %d %d %d %d\n", exact_global[0], exact_global[1], exact_global[2], braced_global, braced_scalar, nested_scalar.a[1], nested_scalar.b, designated_global[2] + designated_global[3]);
    return 0;
}
