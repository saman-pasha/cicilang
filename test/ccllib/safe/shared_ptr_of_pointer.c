/* <memory.pl>: a shared_ptr's object is a value with no pointer in it, as a container's element is (decision 2) (1.1.3) */
#include <memory.pl>
int main(void) {
    shared_ptr<char *> p;
    return 0;
}
