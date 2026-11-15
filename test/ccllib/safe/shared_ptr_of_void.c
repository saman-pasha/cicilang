/* <memory.pl>: a shared_ptr's object is no void (1.1.3) */
#include <memory.pl>
int main(void) {
    shared_ptr<void> p;
    return 0;
}
