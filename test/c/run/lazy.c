/* AN INSTANCE'S FUNCTIONS ARE MADE AT THEIR FIRST CALL, AND A CALL FINDS ITS INSTANCE BY ITS FIRST ARGUMENT (0.274;
   CCLLIB.md's phase 1a): stack<T> over lazy.pl, whose fn_stack/3 gives one function at a time. push(s, 5) is
   stack_int_push(&s, 5), made here with the stack_int_room that its text calls; size(p) over a pointer hands the
   pointer; fill has two forms, told by the count of the arguments; s[0], s == c, clone(s) and the literal ask for
   _index, _eq, _clone and _from. stack_int_never is never called, and the unit does not hold it. size over a
   stack<double> is the program's own function below, whose first parameter takes that instance: it is the one called
   for one, and the instance's for a stack<int>. lazy.pl.h, the macro file's header, brings realloc and free: this
   file includes no <stdlib.h> */
#include <stdio.h>
#include "lazy.pl"
static size_t size(const stack<double> *p) { return 100 + p->len; }
static size_t count(const stack<int> *p) { return size(p); }
int main(void) {
    stack<int> s;
    push(s, 5);
    push(s, 3);
    stack_int_push(&s, 9);
    printf("%zu %zu %d\n", size(s), count(&s), *top(s));
    fill(s, 7);
    printf("%d %d\n", pop(s), s[0]);
    fill(s, 4, 1);
    c := clone(s);
    stack<double> d = [1.5, 2.5];
    printf("%zu %d %g %zu\n", size(c), s == c, pop(d), size(&d));
    return 0;
}
