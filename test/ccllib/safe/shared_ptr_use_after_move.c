/* <memory.pl>: a shared_ptr moved into a call is empty here (1.1.3) */
#include <memory.pl>
static int take(shared_ptr<int> p) { return *p; }
int main(void) {
    shared_ptr<int> p = make_shared<int>(1);
    int n = take(p);
    return *p + n;
}
