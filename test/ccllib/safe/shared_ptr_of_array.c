/* <memory.pl>: a shared_ptr's object is no array; a type of no bound has no word (1.1.3) */
#include <memory.pl>
int main(void) {
    shared_ptr<int[3]> p;
    return 0;
}
