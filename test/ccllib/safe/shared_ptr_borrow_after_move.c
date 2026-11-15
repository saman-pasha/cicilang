/* <memory.pl>: a borrow of a shared_ptr's object ends where the handle is moved into a call (1.1.3) */
#include <memory.pl>
static int take(shared_ptr<int> p) { return *p; }
int main(void) {
    shared_ptr<int> p = make_shared<int>(1);
    int *b = get(p);
    int n = take(p);
    return *b + n;
}
