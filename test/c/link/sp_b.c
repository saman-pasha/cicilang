/* the second unit of sp_a.c (1.6.5) */
#include <memory.pl>
int from_b(void) {
    shared_ptr<int> q = make_shared<int>(7);
    return *q + 10 * unique(q);
}
int count_in_b(shared_ptr<int> *p) {
    shared_ptr<int> c = clone(*p);
    return (int)use_count(c);
}
