/* two units over <memory.pl> (1.6.5): each makes shared_ptr<int> and calls its functions, and a handle that one unit
   made is cloned and counted in the other, over the one pool of the program (the review's r15: through 1.6.4 each unit
   had its pool, the linker kept one unit's `unique', and a call from the other aborted) -- with sp_b.c */
#include <stdio.h>
#include <memory.pl>
int from_b(void);
int count_in_b(shared_ptr<int> *p);
int main(void) {
    shared_ptr<int> p = make_shared<int>(5);
    printf("a %d %d\n", *p, unique(p));
    printf("b %d\n", from_b());
    printf("count %d %d\n", count_in_b(&p), (int)use_count(p));
    return 0;
}
