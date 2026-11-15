/* <memory.pl>: a weak_ptr's object is a value with no pointer in it, as a shared_ptr's (decision 2) (1.1.5) */
#include <memory.pl>
int main(void) {
    weak_ptr<char *> w;
    return 0;
}
