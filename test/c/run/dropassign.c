/* AN ASSIGNMENT OVER AN OBJECT THAT ITS SCOPE DROPS (0.287): the right side's value is made, the object's old value is
   dropped, and the new value is stored -- as C++'s assignment frees what its object held, and as a string's `s = t'
   needs. The right side reads the old value before it goes (`a = next(&a)'); an object assigned to itself keeps its
   value; a parameter by value and an object that hides another of its name are assigned so too. track<T>'s drop
   prints the name that it frees, so each line of a drop shows where the old value went. Nothing is freed by hand. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "autodrop.pl"
static track<int> make(const char *tag, int n) {
    printf("make %s\n", tag);
    track<int> t = tracked<int>(tag, n);
    return t;
}
static track<int> next(const track<int> *old) {
    printf("next of %s\n", old->tag);
    track<int> t = tracked<int>("next", old->val + 1);
    return t;
}
static int param(track<int> p) {
    p = make("param.new", p.val * 2);
    return p.val;
}
int main(void) {
    track<int> a = tracked<int>("a.1", 1);
    a = make("a.2", 2);
    printf("a %s %d\n", a.tag, a.val);
    a = next(&a);
    printf("a %s %d\n", a.tag, a.val);
    track<int> b = tracked<int>("b.1", 10);
    a = b;
    printf("a %s %d\n", a.tag, a.val);
    a = a;
    printf("a %s %d\n", a.tag, a.val);
    track<int> e;
    e = make("e.1", 5);
    for (int i = 0; i < 3; i++) {
        e = make(i == 0 ? "e.2" : i == 1 ? "e.3" : "e.4", i);
    }
    printf("e %s %d\n", e.tag, e.val);
    track<int> arg = make("arg", 21);
    printf("param %d\n", param(arg));
    {
        track<int> a = tracked<int>("inner.a", 7);
        a = make("inner.a2", 8);
        printf("inner %s\n", a.tag);
    }
    if (a.val == 10) a = make("a.3", 3);
    printf("a %s %d\n", a.tag, a.val);
    return 0;
}
